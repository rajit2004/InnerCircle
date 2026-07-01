package com.innercircle.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.innercircle.dto.ChatHistoryResponse;
import com.innercircle.dto.ChatRequest;
import com.innercircle.dto.ChatResponse;
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
     * BUG FIX (Round 6): Replaces the old streamChat()-based /sync endpoint, which
     * worked by accident — .block() on a Flux<String> built for SSE token deltas
     * does drain to a usable string, but the method was never named or shaped to
     * be a normal request/response call, and ChatController was returning the
     * raw string instead of wrapping it in ChatResponse. This is the real,
     * intentional non-streaming implementation: regular JSON request to Groq
     * (no "stream": true), regular JSON response back to the client.
     */
    @Transactional
    public ChatResponse chatDirect(ChatRequest request, User user) {
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
        // Intentionally no "stream": true — see method doc above.

        String response;
        try {
            response = webClient.post()
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
        } catch (Exception e) {
            log.error("Groq request failed: {}", e.getMessage(), e);
            throw new RuntimeException("Failed to reach AI service: " + e.getMessage());
        }

        String reply;
        try {
            JsonNode root = objectMapper.readTree(response);
            JsonNode choices = root.path("choices");
            if (choices.isEmpty()) {
                log.error("Groq returned no choices: {}", response);
                throw new RuntimeException("AI service returned an empty response");
            }
            reply = choices.get(0).path("message").path("content").asText("");
        } catch (Exception e) {
            log.error("Failed to parse Groq response: {} — raw body: {}", e.getMessage(), response);
            throw new RuntimeException("Failed to parse AI response: " + e.getMessage());
        }

        if (reply.isBlank()) {
            log.warn("Groq returned a blank reply for persona {}", persona.getName());
        } else {
            Message assistantMsg = new Message();
            assistantMsg.setConversation(conversation);
            assistantMsg.setRole("assistant");
            assistantMsg.setContent(reply);
            messageRepository.save(assistantMsg);

            String finalReply = reply;
            Mono.fromRunnable(() -> {
                try {
                    memoryService.extractAndStoreMemory(
                            user,
                            request.getPersonaId().toString(),
                            request.getContent(),
                            finalReply
                    );
                } catch (Exception e) {
                    log.warn("Memory extraction failed: {}", e.getMessage());
                }
            }).subscribeOn(Schedulers.boundedElastic()).subscribe();
        }

        return new ChatResponse(reply, conversation.getId());
    }

    // FEATURE (chat history, 2026-07-02): There was previously no way to fetch
    // past messages for a persona at all -- the frontend's ChatScreen kept
    // messages and conversationId purely in local widget state, which meant
    // every time the screen was closed and reopened, it started completely
    // fresh: no history shown, AND a brand new Conversation created server-side
    // with zero prior messages. That second part is why in-chat style requests
    // like "reply shorter" or "be more casual" appeared to reset on reopen --
    // they weren't actually forgotten, they were just sitting in an orphaned
    // conversation that the new session never loaded, so Groq never saw them
    // again in the message history sent as context.
    //
    // This returns the most recent conversation for the given persona (if
    // any) and its full message list, so the frontend can restore both the
    // visible chat history AND the conversationId to continue from, instead
    // of silently starting a new conversation every time.
    public ChatHistoryResponse getHistory(UUID personaId, User user) {
        Persona persona = personaRepository.findById(personaId)
                .orElseThrow(() -> new ResourceNotFoundException("Persona not found"));

        Optional<Conversation> conversationOpt =
                conversationRepository.findFirstByUserAndPersonaOrderByUpdatedAtDesc(user, persona);

        if (conversationOpt.isEmpty()) {
            return new ChatHistoryResponse(null, List.of());
        }

        Conversation conversation = conversationOpt.get();
        List<ChatHistoryResponse.MessageDto> messages = messageRepository
                .findByConversationOrderByCreatedAtAsc(conversation)
                .stream()
                .map(m -> new ChatHistoryResponse.MessageDto(m.getRole(), m.getContent(), m.getCreatedAt()))
                .toList();

        return new ChatHistoryResponse(conversation.getId(), messages);
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