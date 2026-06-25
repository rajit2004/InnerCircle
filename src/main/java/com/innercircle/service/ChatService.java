package com.innercircle.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.innercircle.dto.ChatRequest;
import com.innercircle.dto.ChatResponse;
import com.innercircle.exception.ResourceNotFoundException;
import com.innercircle.exception.UnauthorizedException;
import com.innercircle.model.*;
import com.innercircle.repository.ConversationRepository;
import com.innercircle.repository.MessageRepository;
import com.innercircle.repository.MemoryRepository;
import com.innercircle.repository.PersonaRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatusCode;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

import java.util.*;

@Service
@RequiredArgsConstructor
public class ChatService {

    private final WebClient webClient;
    private final PersonaRepository personaRepository;
    private final ConversationRepository conversationRepository;
    private final MessageRepository messageRepository;
    private final MemoryRepository memoryRepository;
    private final PersonaService personaService;
    private final MemoryService memoryService;

    @Value("${groq.api-key}")
    private String groqApiKey;

    @Value("${groq.model}")
    private String groqModel;

    @Value("${groq.url}")
    private String groqUrl;

    private final ObjectMapper objectMapper = new ObjectMapper();

    // ---------- Reactive streaming method (existing) ----------
    public Flux<String> streamChat(ChatRequest request, User user) {
        System.out.println(">>> ChatService.streamChat() START for persona: " + request.getPersonaId());

        try {
            // Check tier
            if (!personaService.isPersonaAccessible(user, request.getPersonaId())) {
                System.err.println("❌ Tier check failed");
                return Flux.error(new UnauthorizedException("Upgrade to premium"));
            }
            System.out.println("✅ Tier check passed");

            Persona persona = personaRepository.findById(request.getPersonaId())
                    .orElseThrow(() -> new ResourceNotFoundException("Persona not found"));
            System.out.println("✅ Persona found: " + persona.getName());

            final Conversation conversation;
            if (request.getConversationId() != null) {
                conversation = conversationRepository.findById(request.getConversationId())
                        .orElseThrow(() -> new ResourceNotFoundException("Conversation not found"));
                if (!conversation.getUser().getId().equals(user.getId())) {
                    return Flux.error(new UnauthorizedException("No access to this conversation"));
                }
            } else {
                conversation = new Conversation();
                conversation.setUser(user);
                conversation.setPersona(persona);
                conversationRepository.save(conversation);
            }
            System.out.println("✅ Conversation ready: " + conversation.getId());

            // Save user message
            Message userMsg = new Message();
            userMsg.setConversation(conversation);
            userMsg.setRole("user");
            userMsg.setContent(request.getContent());
            messageRepository.save(userMsg);
            System.out.println("✅ User message saved");

            // Get recent messages
            List<Message> recent = messageRepository.findByConversationOrderByCreatedAtAsc(conversation);
            recent = recent.stream().skip(Math.max(0, recent.size() - 20)).toList();
            System.out.println("✅ Retrieved " + recent.size() + " recent messages");

            // Get memories
            List<Memory> memories = memoryRepository.findByUserAndPersonaOrderByImportanceDesc(user, persona);
            String memoryText = memories.stream()
                    .limit(3)
                    .map(Memory::getFact)
                    .reduce((a, b) -> a + "\n" + b)
                    .orElse("");
            System.out.println("✅ Retrieved memories: " + (memoryText.isEmpty() ? "none" : memoryText));

            // Build Groq request
            List<Map<String, String>> messages = new ArrayList<>();
            messages.add(Map.of("role", "system", "content",
                    persona.getSystemPrompt() + "\n\nFacts about user:\n" + memoryText));
            for (Message m : recent) {
                messages.add(Map.of("role", m.getRole(), "content", m.getContent()));
            }
            System.out.println("✅ Built Groq messages (" + messages.size() + " entries)");

            Map<String, Object> body = new HashMap<>();
            body.put("model", groqModel);
            body.put("messages", messages);
            body.put("stream", true);
            body.put("max_tokens", 300);
            System.out.println("✅ Groq request body ready. Model: " + groqModel);

            final List<String> tokenAccumulator = Collections.synchronizedList(new ArrayList<>());
            System.out.println("🚀 About to send request to Groq...");

            return webClient.post()
                    .uri(groqUrl)
                    .header("Authorization", "Bearer " + groqApiKey)
                    .bodyValue(body)
                    .retrieve()
                    .onStatus(HttpStatusCode::isError, response ->
                            response.bodyToMono(String.class)
                                    .flatMap(errorBody -> {
                                        System.err.println("🔥 Groq API error: " + errorBody);
                                        return Mono.error(new RuntimeException("Groq API error: " + errorBody));
                                    })
                    )
                    .bodyToFlux(String.class)
                    .doOnSubscribe(sub -> System.out.println("✅ Groq request subscribed"))
                    .flatMap(chunk -> {
                        if (chunk.startsWith("data: ")) {
                            String json = chunk.substring(6).trim();
                            if ("[DONE]".equals(json)) {
                                return Flux.empty();
                            }
                            try {
                                JsonNode node = objectMapper.readTree(json);
                                JsonNode choices = node.path("choices");
                                if (choices.isEmpty()) return Flux.empty();
                                String token = choices.get(0).path("delta").path("content").asText("");
                                if (!token.isEmpty()) {
                                    tokenAccumulator.add(token);
                                    return Flux.just(token);
                                }
                                return Flux.empty();
                            } catch (Exception e) {
                                System.err.println("⚠️ Parse error: " + e.getMessage());
                                return Flux.empty();
                            }
                        }
                        return Flux.empty();
                    })
                    .doOnNext(token -> System.out.println("📝 Token: " + token))
                    .doOnComplete(() -> {
                        System.out.println("✅ Stream complete");
                        String fullReply = String.join("", tokenAccumulator);
                        if (!fullReply.isEmpty()) {
                            Message assistantMsg = new Message();
                            assistantMsg.setConversation(conversation);
                            assistantMsg.setRole("assistant");
                            assistantMsg.setContent(fullReply);
                            messageRepository.save(assistantMsg);
                            System.out.println("✅ Assistant reply saved");

                            Mono.fromRunnable(() -> {
                                try {
                                    memoryService.extractAndStoreMemory(
                                            user,
                                            request.getPersonaId().toString(),
                                            request.getContent(),
                                            fullReply
                                    );
                                } catch (Exception e) {
                                    System.err.println("⚠️ Memory extraction failed: " + e.getMessage());
                                }
                            }).subscribeOn(Schedulers.boundedElastic()).subscribe();
                        }
                    })
                    .doOnError(e -> {
                        System.err.println("❌ Chat stream error: " + e.getMessage());
                        e.printStackTrace();
                    });

        } catch (Exception e) {
            System.err.println("❌ Exception in ChatService.streamChat(): " + e.getMessage());
            e.printStackTrace();
            return Flux.error(e);
        }
    }

    // ---------- Synchronous wrapper for non‑reactive endpoints ----------
    /**
     * Synchronous wrapper for streamChat – collects the full response and returns a ChatResponse.
     * This is intended for testing/non‑reactive endpoints.
     * For production, use the reactive streamChat directly.
     */
    public ChatResponse processChat(ChatRequest request, User user) {
        String fullReply = streamChat(request, user)
                .collectList()
                .block()                // block until the stream completes
                .stream()
                .reduce("", (a, b) -> a + b);
        return new ChatResponse(fullReply);
    }
}