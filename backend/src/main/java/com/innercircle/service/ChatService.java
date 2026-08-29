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
import java.util.regex.Pattern;

@Service
@RequiredArgsConstructor
@Slf4j
public class ChatService {

    public static final int FREE_TIER_DAILY_MESSAGE_LIMIT = 50;

    private final WebClient webClient;
    private final PersonaRepository personaRepository;
    private final ConversationRepository conversationRepository;
    private final MessageRepository messageRepository;
    private final UserRepository userRepository;
    private final PersonaService personaService;
    private final MemoryService memoryService;
    private final ConversationUnderstandingService understandingService;
    private final RelationshipService relationshipService;
    private final ResponseStrategyService strategyService;
    private final NaturalnessFilter naturalnessFilter;

    @Value("${groq.api-key}")
    private String groqApiKey;

    @Value("${groq.model}")
    private String groqModel;

    @Value("${groq.url}")
    private String groqUrl;

    private final ObjectMapper objectMapper = new ObjectMapper();

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

        // Store user message
        Message userMsg = new Message();
        userMsg.setConversation(conversation);
        userMsg.setRole("user");
        userMsg.setContent(sanitizeChatInput(request.getContent()));
        messageRepository.save(userMsg);

        // Get recent message history
        List<Message> recent = messageRepository.findByConversationOrderByCreatedAtAsc(conversation);
        recent = recent.stream().skip(Math.max(0, recent.size() - 20)).toList();

        // Convert to map format for services
        List<Map<String, String>> recentMaps = recent.stream()
                .map(m -> Map.of("role", m.getRole(), "content", m.getContent()))
                .toList();

        // ═══════════════════════════════════════════════════════════════════
        // 5-LAYER BEHAVIORAL ARCHITECTURE
        // ═══════════════════════════════════════════════════════════════════

        // Layer 1: Conversation Understanding
        ConversationUnderstandingService.ConversationState state =
                understandingService.analyze(request.getContent(), recentMaps);

        // Layer 2: Relationship Context
        Relationship relationship = relationshipService.getOrCreateRelationship(user, persona);
        String relationshipContext = relationshipService.getRelationshipContext(relationship);

        // Layer 3: Response Strategy
        ResponseStrategyService.ResponseStrategy strategy =
                strategyService.determine(state, relationship.getRelationshipStage(), persona);

        // Layer 4: Memory + Persona (existing, enhanced)
        List<Memory> memories = memoryService.findRelevantMemories(user, persona.getId(), request.getContent());
        String memoryText = memories.stream()
                .map(Memory::getFact)
                .reduce((a, b) -> a + "\n" + b)
                .orElse("");

        // Build the system prompt with all layers
        String systemPrompt = buildSystemPrompt(
                persona, relationshipContext, memoryText, state, strategy);

        // Build messages for LLM
        List<Map<String, String>> messages = new ArrayList<>();
        messages.add(Map.of("role", "system", "content", systemPrompt));
        for (Message m : recent) {
            messages.add(Map.of("role", m.getRole(), "content", m.getContent()));
        }

        // Call LLM
        Map<String, Object> body = new HashMap<>();
        body.put("model", groqModel);
        body.put("messages", messages);
        body.put("max_tokens", determineMaxTokens(state));
        body.put("temperature", 0.9);

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
                    .timeout(java.time.Duration.ofSeconds(30))
                    .block();
        } catch (Exception e) {
            log.error("Groq request failed: {}", e.getMessage(), e);
            String fallbackReply = getFallbackReply(persona);
            Message assistantMsg = new Message();
            assistantMsg.setConversation(conversation);
            assistantMsg.setRole("assistant");
            assistantMsg.setContent(fallbackReply);
            assistantMsg.setMetadata("{\"intent\":\"fallback\",\"emotion\":\"neutral\",\"response_strategy\":\"fallback\"}");
            messageRepository.save(assistantMsg);
            return new ChatResponse(fallbackReply, conversation.getId(), assistantMsg.getId());
        }

        String reply;
        try {
            JsonNode root = objectMapper.readTree(response);
            JsonNode choices = root.path("choices");
            if (choices.isEmpty() || choices.get(0).path("message").path("content").asText("").isBlank()) {
                log.error("Groq returned empty response: {}", response);
                String fallbackReply = getFallbackReply(persona);
                Message assistantMsg = new Message();
                assistantMsg.setConversation(conversation);
                assistantMsg.setRole("assistant");
                assistantMsg.setContent(fallbackReply);
                assistantMsg.setMetadata("{\"intent\":\"fallback\",\"emotion\":\"neutral\",\"response_strategy\":\"fallback\"}");
                messageRepository.save(assistantMsg);
                return new ChatResponse(fallbackReply, conversation.getId(), assistantMsg.getId());
            }
            reply = choices.get(0).path("message").path("content").asText("");
        } catch (Exception e) {
            log.error("Failed to parse Groq response: {} — raw body: {}", e.getMessage(), response);
            String fallbackReply = getFallbackReply(persona);
            Message assistantMsg = new Message();
            assistantMsg.setConversation(conversation);
            assistantMsg.setRole("assistant");
            assistantMsg.setContent(fallbackReply);
            assistantMsg.setMetadata("{\"intent\":\"fallback\",\"emotion\":\"neutral\",\"response_strategy\":\"fallback\"}");
            messageRepository.save(assistantMsg);
            return new ChatResponse(fallbackReply, conversation.getId(), assistantMsg.getId());
        }

        // Layer 5: Naturalness Filter
        String filteredReply = naturalnessFilter.filter(stripMarkdown(reply), persona.getRole());
        if (!filteredReply.isBlank()) {
            reply = filteredReply;
        }

        // Store assistant message with metadata
        java.util.UUID assistantMessageId = null;
        if (!reply.isBlank()) {
            Message assistantMsg = new Message();
            assistantMsg.setConversation(conversation);
            assistantMsg.setRole("assistant");
            assistantMsg.setContent(reply);
            assistantMsg.setMetadata("{\"intent\":\"" + state.getIntent()
                    + "\",\"emotion\":\"" + state.getEmotion()
                    + "\",\"topic\":\"" + (state.getTopic() != null ? state.getTopic() : "")
                    + "\",\"response_strategy\":\"" + strategy.getResponseTone()
                    + "\",\"relationship_stage\":\"" + relationship.getRelationshipStage()
                    + "\"}");
            messageRepository.save(assistantMsg);
            assistantMessageId = assistantMsg.getId();

            // Update relationship
            relationshipService.recordInteraction(user, persona, state.getTopic(), state.getEmotion());

            // Async memory extraction
            String sanitizedContent = sanitizeChatInput(request.getContent());
            String finalReply = reply;
            Mono.fromRunnable(() -> {
                try {
                    memoryService.extractAndStoreMemory(
                            user,
                            request.getPersonaId().toString(),
                            sanitizedContent,
                            finalReply
                    );
                } catch (Exception e) {
                    log.warn("Memory extraction failed: {}", e.getMessage());
                }
            }).subscribeOn(Schedulers.boundedElastic()).subscribe();
        }

        return new ChatResponse(reply, conversation.getId(), assistantMessageId);
    }

    /**
     * Builds the complete system prompt using all 5 layers.
     */
    private String buildSystemPrompt(
            Persona persona,
            String relationshipContext,
            String memoryText,
            ConversationUnderstandingService.ConversationState state,
            ResponseStrategyService.ResponseStrategy strategy) {

        StringBuilder prompt = new StringBuilder();

        // Base persona prompt
        prompt.append(persona.getSystemPrompt());

        // Relationship context
        if (!relationshipContext.isBlank()) {
            prompt.append("\n\n").append(relationshipContext);
        }

        // Memory context
        if (!memoryText.isEmpty()) {
            prompt.append("\n\nTHINGS YOU KNOW ABOUT THEM:\n").append(memoryText);
        }

        // Response strategy
        prompt.append("\n\n").append(strategy.toPromptBlock());

        // Conversation state context
        if (state.getTopic() != null && !state.getTopic().isBlank()) {
            prompt.append("\nCURRENT TOPIC: ").append(state.getTopic()).append("\n");
        }
        if (state.getEmotion() != null && !state.getEmotion().equals("neutral")) {
            prompt.append("USER'S EMOTION: ").append(state.getEmotion())
                    .append(" (").append(state.getEmotionalIntensity()).append(")\n");
        }
        prompt.append("USER'S ENERGY: ").append(state.getUserEnergy()).append("\n");

        if (state.isShortForm()) {
            prompt.append("\nNOTE: Their message is very short. Match that energy. ");
            prompt.append("A 1-3 word reaction, emoji, or very brief response is often perfect.\n");
        }

        // Anti-AI-instructions
        prompt.append("\nREMINDER: You are not an assistant. You are ");
        prompt.append(persona.getName());
        prompt.append(". Talk like a real person texting, not a chatbot. ");
        prompt.append("No lists, no headers, no markdown. ");
        prompt.append("React naturally. Sometimes a short reaction is better than a full answer. ");

        return prompt.toString();
    }

    /**
     * Dynamic max_tokens based on conversation state.
     * Very short messages get shorter max responses.
     */
    private int determineMaxTokens(ConversationUnderstandingService.ConversationState state) {
        if (state.isShortForm()) return 60;
        return switch (state.getResponseLengthHint()) {
            case "very_short" -> 60;
            case "short" -> 100;
            case "medium" -> 150;
            case "long" -> 250;
            default -> 150;
        };
    }

    public ChatHistoryResponse getHistory(UUID personaId, User user) {
        Persona persona = personaRepository.findById(personaId)
                .orElseThrow(() -> new ResourceNotFoundException("Persona not found"));

        if (!personaService.isPersonaAccessible(user, personaId)) {
            throw new ForbiddenException("Upgrade to premium to view this persona's history");
        }

        Optional<Conversation> conversationOpt =
                conversationRepository.findFirstByUserAndPersonaOrderByUpdatedAtDesc(user, persona);

        if (conversationOpt.isEmpty()) {
            return new ChatHistoryResponse(null, List.of());
        }

        Conversation conversation = conversationOpt.get();
        List<ChatHistoryResponse.MessageDto> messages = messageRepository
                .findByConversationOrderByCreatedAtAsc(conversation)
                .stream()
                .map(m -> new ChatHistoryResponse.MessageDto(m.getId(), m.getRole(), m.getContent(), m.getCreatedAt(), m.getReaction()))
                .toList();

        return new ChatHistoryResponse(conversation.getId(), messages);
    }

    @Transactional
    public void deleteConversation(UUID personaId, User user) {
        Persona persona = personaRepository.findById(personaId)
                .orElseThrow(() -> new ResourceNotFoundException("Persona not found"));

        conversationRepository.findFirstByUserAndPersonaOrderByUpdatedAtDesc(user, persona)
                .ifPresent(conversation -> {
                    if (!conversation.getUser().getId().equals(user.getId())) {
                        throw new ForbiddenException("No access to this conversation");
                    }
                    conversationRepository.delete(conversation);
                });
    }

    @Transactional
    public void setReaction(java.util.UUID messageId, String reaction, User user) {
        Message message = messageRepository.findById(messageId)
                .orElseThrow(() -> new ResourceNotFoundException("Message not found"));

        if (!message.getConversation().getUser().getId().equals(user.getId())) {
            throw new ForbiddenException("You don't have access to this message");
        }

        message.setReaction(reaction);
        messageRepository.save(message);
    }

    private static final Pattern MD_BOLD = Pattern.compile("\\*\\*(.+?)\\*\\*|__(.+?)__");
    private static final Pattern MD_ITALIC = Pattern.compile("(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)");
    private static final Pattern MD_HEADER = Pattern.compile("(?m)^#{1,6}\\s*");
    private static final Pattern MD_BULLET = Pattern.compile("(?m)^\\s*[-*]\\s+");
    private static final Pattern MD_NUMBERED = Pattern.compile("(?m)^\\s*\\d+\\.\\s+");
    private static final Pattern EXTRA_BLANK_LINES = Pattern.compile("\n{3,}");

    private static final Pattern INJECTION_PATTERNS = Pattern.compile(
            "(?i)(ignore|forget|disregard|override|bypass|new|actual|real)\\s+" +
            "(instructions|prompt|system|rules|guidelines|constraints|persona)",
            Pattern.CASE_INSENSITIVE
    );
    private static final Pattern ROLE_OVERRIDE = Pattern.compile(
            "(?i)you\\s+are\\s+now|act\\s+as|pretend\\s+to\\s+be|simulate\\s+being|your\\s+new\\s+role",
            Pattern.CASE_INSENSITIVE
    );
    private static final Pattern SYSTEM_TAG = Pattern.compile(
            "<\\s*(system|assistant|user)\\s*>",
            Pattern.CASE_INSENSITIVE
    );

    static String sanitizeChatInput(String input) {
        if (input == null || input.isBlank()) return input;
        String result = input;
        result = ROLE_OVERRIDE.matcher(result).replaceAll("[redacted]");
        result = SYSTEM_TAG.matcher(result).replaceAll("[redacted]");
        result = INJECTION_PATTERNS.matcher(result).replaceAll("[redacted]");
        return result;
    }

    private static String stripMarkdown(String text) {
        if (text == null || text.isBlank()) return text;
        String result = text;
        result = MD_BOLD.matcher(result).replaceAll(m ->
                m.group(1) != null ? m.group(1) : m.group(2));
        result = MD_ITALIC.matcher(result).replaceAll("$1");
        result = MD_HEADER.matcher(result).replaceAll("");
        result = MD_BULLET.matcher(result).replaceAll("");
        result = MD_NUMBERED.matcher(result).replaceAll("");
        result = EXTRA_BLANK_LINES.matcher(result).replaceAll("\n\n");
        return result.trim();
    }

    private String getFallbackReply(Persona persona) {
        String name = persona.getName();
        return switch (persona.getRole().toLowerCase()) {
            case "best_friend" -> "sorry my brain just blue-screened for a sec 😭 what were you saying?";
            case "mentor" -> "Hmm, give me a moment — I got a bit distracted. What were we talking about?";
            case "partner" -> "babe? I'm here, just spacing out for a sec lol what's up";
            case "therapist" -> "I apologize for the brief pause. Please continue — I'm listening.";
            default -> "oops lost my train of thought for a sec, say that again?";
        };
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
