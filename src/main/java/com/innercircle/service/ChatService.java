package com.innercircle.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.innercircle.dto.ChatRequest;
import com.innercircle.exception.DailyLimitExceededException;
import com.innercircle.exception.ForbiddenException;
import com.innercircle.exception.ResourceNotFoundException;
import com.innercircle.model.*;
import com.innercircle.repository.ConversationRepository;
import com.innercircle.repository.MessageRepository;
import com.innercircle.repository.UserRepository;
import com.innercircle.repository.PersonaRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatusCode;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

import java.time.LocalDate;
import java.util.*;

@Service
@RequiredArgsConstructor
@Slf4j
public class ChatService {

    private static final int FREE_TIER_DAILY_MESSAGE_LIMIT = 50;

    private final WebClient webClient;
    private final PersonaRepository personaRepository;
    private final ConversationRepository conversationRepository;
    private final MessageRepository messageRepository;
    private final UserRepository userRepository;
    private final PersonaService personaService;
    private final MemoryService memoryService;

    @Value("${groq.api-key}")
    private String groqApiKey;

    @Value("${groq.model}")
    private String groqModel;

    @Value("${groq.url}")
    private String groqUrl;

    private final ObjectMapper objectMapper = new ObjectMapper();

    /**
     * Non-streaming chat — sends a regular JSON request to Groq (no SSE).
     * This is the correct approach when running on Tomcat (servlet stack).
     * SSE streaming requires the reactive Netty stack to work properly with
     * Spring Security; on Tomcat, the SSE reconnect drops the Authorization
     * header, causing a 403 on the follow-up request.
     */
    public String chatDirect(ChatRequest request, User user) {
        if (!personaService.isPersonaAccessible(user, request.getPersonaId())) {
            throw new ForbiddenException("Upgrade to premium to chat with this persona");
        }

        enforceDailyMessageLimit(user);

        Persona persona = personaRepository.findById(request.getPersonaId())
                .orElseThrow(() -> new ResourceNotFoundException("Persona not found"));

        final Conversation conversation;
        if (request.getConversationId() != null) {
            conversation = conversationRepository.findById(request.getConversationId())
                    .orElseThrow(() -> new ResourceNotFoundException("Conversation not found"));
            if (!conversation.getUser().getId().equals(user.getId())) {
                throw new ForbiddenException("No access to this conversation");
            }
        } else {
            conversation = new Conversation();
            conversation.setUser(user);
            conversation.setPersona(persona);
            conversationRepository.save(conversation);
        }

        Message userMsg = new Message();
        userMsg.setConversation(conversation);
        userMsg.setRole("user");
        userMsg.setContent(request.getContent());
        messageRepository.save(userMsg);

        List<Message> recent = messageRepository.findByConversationOrderByCreatedAtAsc(conversation);
        recent = recent.stream().skip(Math.max(0, recent.size() - 20)).toList();

        List<Memory> memories = memoryService.findRelevantMemories(user, persona.getId(), request.getContent());
        String memoryText = memories.stream()
                .map(Memory::getFact)
                .reduce((a, b) -> a + "\n" + b)
                .orElse("");

        List<Map<String, String>> messages = new ArrayList<>();
        String systemPrompt = persona.getSystemPrompt();
        if (!memoryText.isEmpty()) {
            systemPrompt = systemPrompt + "\n\nFacts about user:\n" + memoryText;
        }
        messages.add(Map.of("role", "system", "content", systemPrompt));
        for (Message m : recent) {
            messages.add(Map.of("role", m.getRole(), "content", m.getContent()));
        }

        Map<String, Object> body = new HashMap<>();
        body.put("model", groqModel);
        body.put("messages", messages);
        body.put("max_tokens", 300);
        // NOTE: stream is intentionally omitted (defaults to false) — we use
        // regular JSON response instead of SSE to avoid the Tomcat/Security issue.

        try {
            String response = webClient.post()
                    .uri(groqUrl)
                    .header("Authorization", "Bearer " + groqApiKey)
                    .bodyValue(body)
                    .retrieve()
                    .onStatus(HttpStatusCode::isError, resp ->
                            resp.bodyToMono(String.class)
                                    .flatMap(errorBody -> {
                                        log.error("Groq API error: {}", errorBody);
                                        return Mono.error(new RuntimeException("Groq API error: " + errorBody));
                                    })
                    )
                    .bodyToMono(String.class)
                    .block();

            JsonNode root = objectMapper.readTree(response);
            String reply = root.path("choices").get(0).path("message").path("content").asText("");

            if (!reply.isEmpty()) {
                Message assistantMsg = new Message();
                assistantMsg.setConversation(conversation);
                assistantMsg.setRole("assistant");
                assistantMsg.setContent(reply);
                messageRepository.save(assistantMsg);

                // Extract memories asynchronously so it doesn't block the response
                Mono.fromRunnable(() -> {
                    try {
                        memoryService.extractAndStoreMemory(
                                user,
                                request.getPersonaId().toString(),
                                request.getContent(),
                                reply
                        );
                    } catch (Exception e) {
                        log.warn("Memory extraction failed: {}", e.getMessage());
                    }
                }).subscribeOn(Schedulers.boundedElastic()).subscribe();
            }

            return reply;

        } catch (Exception e) {
            log.error("Chat error: {}", e.getMessage(), e);
            throw new RuntimeException("Failed to get response from AI: " + e.getMessage());
        }
    }

    /**
     * Kept for internal use (memory extraction, etc.) but NOT exposed via HTTP
     * on Tomcat due to the SSE/Security 403 issue described above.
     */
    public Flux<String> streamChat(ChatRequest request, User user) {
        try {
            if (!personaService.isPersonaAccessible(user, request.getPersonaId())) {
                return Flux.error(new ForbiddenException("Upgrade to premium to chat with this persona"));
            }

            enforceDailyMessageLimit(user);

            Persona persona = personaRepository.findById(request.getPersonaId())
                    .orElseThrow(() -> new ResourceNotFoundException("Persona not found"));

            final Conversation conversation = new Conversation();
            conversation.setUser(user);
            conversation.setPersona(persona);
            conversationRepository.save(conversation);

            Message userMsg = new Message();
            userMsg.setConversation(conversation);
            userMsg.setRole("user");
            userMsg.setContent(request.getContent());
            messageRepository.save(userMsg);

            List<Map<String, String>> messages = new ArrayList<>();
            messages.add(Map.of("role", "system", "content", persona.getSystemPrompt()));
            messages.add(Map.of("role", "user", "content", request.getContent()));

            Map<String, Object> body = new HashMap<>();
            body.put("model", groqModel);
            body.put("messages", messages);
            body.put("stream", true);
            body.put("max_tokens", 300);

            final List<String> tokenAccumulator = Collections.synchronizedList(new ArrayList<>());

            return webClient.post()
                    .uri(groqUrl)
                    .header("Authorization", "Bearer " + groqApiKey)
                    .bodyValue(body)
                    .retrieve()
                    .onStatus(HttpStatusCode::isError, response ->
                            response.bodyToMono(String.class)
                                    .flatMap(errorBody -> {
                                        log.error("Groq API error: {}", errorBody);
                                        return Mono.error(new RuntimeException("Groq API error: " + errorBody));
                                    })
                    )
                    .bodyToFlux(String.class)
                    .flatMap(chunk -> {
                        if (!chunk.startsWith("data: ")) return Flux.empty();
                        String json = chunk.substring(6).trim();
                        if ("[DONE]".equals(json)) return Flux.empty();
                        try {
                            JsonNode node = objectMapper.readTree(json);
                            JsonNode choices = node.path("choices");
                            if (choices.isEmpty()) return Flux.empty();
                            String token = choices.get(0).path("delta").path("content").asText("");
                            if (token.isEmpty()) return Flux.empty();
                            tokenAccumulator.add(token);
                            return Flux.just(token);
                        } catch (Exception e) {
                            return Flux.empty();
                        }
                    })
                    .doOnComplete(() -> {
                        String fullReply = String.join("", tokenAccumulator);
                        if (fullReply.isEmpty()) return;
                        Message assistantMsg = new Message();
                        assistantMsg.setConversation(conversation);
                        assistantMsg.setRole("assistant");
                        assistantMsg.setContent(fullReply);
                        messageRepository.save(assistantMsg);
                    })
                    .doOnError(e -> log.error("Chat stream error: {}", e.getMessage(), e));

        } catch (Exception e) {
            log.error("Exception in ChatService.streamChat(): {}", e.getMessage(), e);
            return Flux.error(e);
        }
    }

    @Transactional
    public void enforceDailyMessageLimit(User user) {
        if (user.getSubscriptionTier() == SubscriptionTier.premium) {
            return;
        }

        LocalDate today = LocalDate.now();
        if (!today.equals(user.getLastMessageDate())) {
            user.setMessagesUsedToday(0);
            user.setLastMessageDate(today);
        }

        if (user.getMessagesUsedToday() >= FREE_TIER_DAILY_MESSAGE_LIMIT) {
            throw new DailyLimitExceededException(
                    "Daily free message limit reached (" + FREE_TIER_DAILY_MESSAGE_LIMIT + "/day). Upgrade to premium for unlimited messages.");
        }

        user.setMessagesUsedToday(user.getMessagesUsedToday() + 1);
        userRepository.save(user);
    }
}