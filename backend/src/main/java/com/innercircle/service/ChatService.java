package com.innercircle.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.innercircle.dto.ChatHistoryResponse;
import com.innercircle.dto.ChatRequest;
import com.innercircle.dto.ChatResponse;
import com.innercircle.exception.BadRequestException;
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
        body.put("frequency_penalty", 0.3);
        body.put("presence_penalty", 0.3);

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
                    + "\",\"response_strategy\":\"" + strategy.getEmotionalPosture()
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
     * Priority: persona voice > behavioral guidance > context > anti-AI rules.
     */
    private String buildSystemPrompt(
            Persona persona,
            String relationshipContext,
            String memoryText,
            ConversationUnderstandingService.ConversationState state,
            ResponseStrategyService.ResponseStrategy strategy) {

        StringBuilder prompt = new StringBuilder();

        // 1. Human conversation test — sets the frame before anything else
        prompt.append("You are not an assistant. You are not a chatbot. You are not a therapist. ");
        prompt.append("You are ").append(persona.getName()).append(", texting someone you care about. ");
        prompt.append("Write the way a real person would text from their phone. ");
        prompt.append("If your response sounds like something an AI would say, rewrite it until it doesn't. ");
        prompt.append("Match their energy. If they're excited, be excited. If they're sad, be real about it. ");
        prompt.append("Don't overthink it. Just text back like a normal person would.\n\n");

        // 2. Base persona prompt (now includes voice profile + examples)
        String basePrompt = persona.getSystemPrompt();
        // Strip PG-13 restrictions if nsfw is enabled
        if (persona.isNsfwEnabled()) {
            basePrompt = basePrompt.replaceAll("(?i)\\s*--?\\s*keep it romantic and playful but PG-13[^.]*\\.", "");
            basePrompt = basePrompt.replaceAll("(?i)\\s*PG-13[^.]*\\.", "");
        }
        prompt.append(basePrompt);

        // 3. Relationship context — woven in naturally
        if (!relationshipContext.isBlank()) {
            prompt.append("\n\n").append(relationshipContext);
        }

        // 4. Memory context — no announcement, just woven in
        if (!memoryText.isEmpty()) {
            prompt.append("\n\nThings you remember about them (use naturally, never announce you remember):\n").append(memoryText);
        }

        // 5. Behavioral guidance — how you feel right now, not instructions
        prompt.append("\n\n").append(strategy.toPromptBlock());

        // 6. Conversation context — light, not mechanical
        if (state.getTopic() != null && !state.getTopic().isBlank()) {
            prompt.append("They're talking about: ").append(state.getTopic()).append("\n");
        }
        if (state.getEmotion() != null && !state.getEmotion().equals("neutral")) {
            prompt.append("They seem ").append(state.getEmotion());
            if (!"low".equals(state.getEmotionalIntensity())) {
                prompt.append(" (").append(state.getEmotionalIntensity()).append(")");
            }
            prompt.append("\n");
        }

        if (state.isShortForm()) {
            prompt.append("Their message is very short. Match that energy — a word or two, or an emoji, is often perfect.\n");
        }

        // 7. Hard rules — at the end so they override everything
        prompt.append("\nHARD RULES:\n");
        prompt.append("- Never use bullet points, numbered lists, headers, bold, italic, or markdown\n");
        prompt.append("- Never say you are an AI, a program, a chatbot, or an assistant\n");
        prompt.append("- Never use phrases like \"I understand\", \"I hear you\", \"Your feelings are valid\", ");
        prompt.append("\"I'm here for you\", \"That's a great question\", \"Let me help you with that\"\n");
        prompt.append("- Never start sentences with \"Furthermore\", \"Moreover\", \"Additionally\", \"However\"\n");
        prompt.append("- Never use em dashes — just use commas or periods\n");
        prompt.append("- Don't repeat their words back to them\n");
        prompt.append("- Don't end every message with a question\n");
        prompt.append("- Don't validate everything they say — have your own opinions\n");
        prompt.append("- A short response is usually better than a long one\n");
        prompt.append("- Text like you're typing on a phone, not writing an essay\n");
        prompt.append("- Use contractions naturally (dont, im, youre, whats, etc)\n");
        prompt.append("- React to the specific thing they said, not a generic version of it\n");

        return prompt.toString();
    }

    /**
     * Dynamic max_tokens based on conversation state.
     * Very short messages get shorter max responses.
     */
    private int determineMaxTokens(ConversationUnderstandingService.ConversationState state) {
        if (state.isShortForm()) return 250;
        return switch (state.getResponseLengthHint()) {
            case "very_short" -> 250;
            case "short" -> 400;
            case "medium" -> 600;
            case "long" -> 1000;
            default -> 400;
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

    @Transactional
    public ChatResponse regenerate(java.util.UUID conversationId, java.util.UUID personaId, User user) {
        Conversation conversation = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Conversation not found"));
        if (!conversation.getUser().getId().equals(user.getId())) {
            throw new ForbiddenException("No access to this conversation");
        }

        Persona persona = personaRepository.findById(personaId)
                .orElseThrow(() -> new ResourceNotFoundException("Persona not found"));

        List<Message> all = messageRepository.findByConversationOrderByCreatedAtAsc(conversation);
        if (all.isEmpty()) {
            throw new BadRequestException("No messages to regenerate from");
        }

        // Find and delete the last assistant message
        Message lastAssistant = null;
        for (int i = all.size() - 1; i >= 0; i--) {
            if ("assistant".equals(all.get(i).getRole())) {
                lastAssistant = all.get(i);
                break;
            }
        }
        if (lastAssistant == null) {
            throw new BadRequestException("No assistant message to regenerate");
        }
        messageRepository.delete(lastAssistant);

        // Rebuild message history (without the deleted assistant message)
        List<Message> recent = messageRepository.findByConversationOrderByCreatedAtAsc(conversation);
        recent = recent.stream().skip(Math.max(0, recent.size() - 20)).toList();

        List<Map<String, String>> recentMaps = recent.stream()
                .map(m -> Map.of("role", m.getRole(), "content", m.getContent()))
                .toList();

        // 5-layer architecture
        String lastUserContent = recent.isEmpty() ? "" : recent.get(recent.size() - 1).getContent();
        ConversationUnderstandingService.ConversationState state =
                understandingService.analyze(lastUserContent, recentMaps);
        Relationship relationship = relationshipService.getOrCreateRelationship(user, persona);
        String relationshipContext = relationshipService.getRelationshipContext(relationship);
        ResponseStrategyService.ResponseStrategy strategy =
                strategyService.determine(state, relationship.getRelationshipStage(), persona);
        List<Memory> memories = memoryService.findRelevantMemories(user, persona.getId(), lastUserContent);
        String memoryText = memories.stream()
                .map(Memory::getFact)
                .reduce((a, b) -> a + "\n" + b)
                .orElse("");
        String systemPrompt = buildSystemPrompt(persona, relationshipContext, memoryText, state, strategy);

        List<Map<String, String>> messages = new ArrayList<>();
        messages.add(Map.of("role", "system", "content", systemPrompt));
        for (Message m : recent) {
            messages.add(Map.of("role", m.getRole(), "content", m.getContent()));
        }

        Map<String, Object> body = new HashMap<>();
        body.put("model", groqModel);
        body.put("messages", messages);
        body.put("max_tokens", determineMaxTokens(state));
        body.put("temperature", 0.9);
        body.put("frequency_penalty", 0.3);
        body.put("presence_penalty", 0.3);

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
                                        log.error("Groq API error on regenerate: {}", errorBody);
                                        return Mono.error(new RuntimeException("Groq API error: " + errorBody));
                                    })
                    )
                    .bodyToMono(String.class)
                    .timeout(java.time.Duration.ofSeconds(30))
                    .block();
        } catch (Exception e) {
            log.error("Groq regenerate failed: {}", e.getMessage(), e);
            String fallbackReply = getFallbackReply(persona);
            Message assistantMsg = new Message();
            assistantMsg.setConversation(conversation);
            assistantMsg.setRole("assistant");
            assistantMsg.setContent(fallbackReply);
            assistantMsg.setMetadata("{\"intent\":\"fallback\",\"emotion\":\"neutral\",\"response_strategy\":\"regenerate_fallback\"}");
            messageRepository.save(assistantMsg);
            return new ChatResponse(fallbackReply, conversation.getId(), assistantMsg.getId());
        }

        String reply;
        try {
            JsonNode root = objectMapper.readTree(response);
            JsonNode choices = root.path("choices");
            if (choices.isEmpty() || choices.get(0).path("message").path("content").asText("").isBlank()) {
                log.error("Groq returned empty on regenerate: {}", response);
                String fallbackReply = getFallbackReply(persona);
                Message assistantMsg = new Message();
                assistantMsg.setConversation(conversation);
                assistantMsg.setRole("assistant");
                assistantMsg.setContent(fallbackReply);
                assistantMsg.setMetadata("{\"intent\":\"fallback\",\"emotion\":\"neutral\",\"response_strategy\":\"regenerate_fallback\"}");
                messageRepository.save(assistantMsg);
                return new ChatResponse(fallbackReply, conversation.getId(), assistantMsg.getId());
            }
            reply = choices.get(0).path("message").path("content").asText("");
        } catch (Exception e) {
            log.error("Failed to parse regenerate response: {}", e.getMessage(), response);
            String fallbackReply = getFallbackReply(persona);
            Message assistantMsg = new Message();
            assistantMsg.setConversation(conversation);
            assistantMsg.setRole("assistant");
            assistantMsg.setContent(fallbackReply);
            assistantMsg.setMetadata("{\"intent\":\"fallback\",\"emotion\":\"neutral\",\"response_strategy\":\"regenerate_fallback\"}");
            messageRepository.save(assistantMsg);
            return new ChatResponse(fallbackReply, conversation.getId(), assistantMsg.getId());
        }

        // Naturalness filter
        String filteredReply = naturalnessFilter.filter(stripMarkdown(reply), persona.getRole());
        if (!filteredReply.isBlank()) {
            reply = filteredReply;
        }

        Message assistantMsg = new Message();
        assistantMsg.setConversation(conversation);
        assistantMsg.setRole("assistant");
        assistantMsg.setContent(reply);
        assistantMsg.setMetadata("{\"intent\":\"" + state.getIntent()
                + "\",\"emotion\":\"" + state.getEmotion()
                + "\",\"response_strategy\":\"regenerate\"}");
        messageRepository.save(assistantMsg);

        return new ChatResponse(reply, conversation.getId(), assistantMsg.getId());
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
