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

    // BUG-PREVENTION (2026-07-03): made public so UserController can report the
    // same limit back to the client for the profile screen's usage display,
    // instead of hardcoding "50" a second time somewhere else and risking the
    // two numbers drifting apart if this one is ever tuned.
    public static final int FREE_TIER_DAILY_MESSAGE_LIMIT = 50;

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
        // BUG FIX (persona voice, 2026-07-02): max_tokens was 300, which is
        // generous enough that the model would happily write full essay-length
        // replies -- e.g. asking Mom for steak got back a structured recipe
        // instead of a text-length reaction. 150 tokens is roughly 3-5 sentences,
        // which comfortably fits the "reply like a real text message" instruction
        // now baked into every persona's system prompt (see schema.sql /
        // update_persona_prompts.sql) while still leaving room for a slightly
        // longer reply when the user actually asks for detail. This is a hard
        // backstop -- even if the model ignores the prompt's length guidance,
        // the response physically can't run on.
        body.put("max_tokens", 150);
        // Slightly higher temperature makes replies feel less formulaic/robotic
        // and more like natural conversation -- the previous unset value fell
        // back to Groq's model default, which trended toward safe, repetitive
        // phrasing.
        body.put("temperature", 0.9);
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

        // BUG FIX (persona voice, 2026-07-02): hard backstop for markdown
        // leaking through despite the system prompt explicitly banning it.
        // Prompt instructions are advisory, not guaranteed -- the model can
        // still slip into **bold**, ## headers, or - bullet lists, especially
        // on longer or more "advice-shaped" replies. The frontend renders
        // message content in a plain Text widget with no markdown parsing, so
        // any of that shows up as literal asterisks/hashes in the chat bubble,
        // which is exactly what made replies look AI-generated instead of
        // human. Stripping it server-side means the fix holds even when the
        // model doesn't fully comply with the prompt.
        reply = stripMarkdown(reply);

        java.util.UUID assistantMessageId = null;

        if (reply.isBlank()) {
            log.warn("Groq returned a blank reply for persona {}", persona.getName());
        } else {
            Message assistantMsg = new Message();
            assistantMsg.setConversation(conversation);
            assistantMsg.setRole("assistant");
            assistantMsg.setContent(reply);
            messageRepository.save(assistantMsg);
            // FEATURE (message reactions, round 12): id is client-generated
            // (GenerationType.UUID), so it's populated on the entity right
            // after save() -- no need for a re-fetch.
            assistantMessageId = assistantMsg.getId();

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

        return new ChatResponse(reply, conversation.getId(), assistantMessageId);
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
                .map(m -> new ChatHistoryResponse.MessageDto(m.getId(), m.getRole(), m.getContent(), m.getCreatedAt(), m.getReaction()))
                .toList();

        return new ChatHistoryResponse(conversation.getId(), messages);
    }

    // FEATURE (message reactions, round 12): sets or clears (reaction ==
    // null) the reaction on a single message. Ownership is checked through
    // the message's conversation, not the message directly -- Message has
    // no user field of its own, only Conversation does (see
    // Conversation.user). A ForbiddenException here (rather than
    // ResourceNotFoundException) is deliberate: the message genuinely
    // exists, the caller just isn't allowed to touch it, which is a
    // meaningfully different case for the frontend to handle/log.
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

    // BUG FIX (persona voice, 2026-07-02): strips common markdown artifacts
    // from a reply before it's saved/returned. Handles the cases the model
    // actually produced in testing: **bold**, __bold__, *italic*, # / ## / ###
    // headers, and "- " or "* " bullet-list markers at the start of a line.
    // Deliberately does NOT touch numbers inside normal sentences (e.g. "I
    // have 2 dogs") -- only strips a numbered-list marker like "1. " when it's
    // at the very start of a line, immediately followed by a real list item.
    // Collapses the extra blank lines markdown lists tend to leave behind so
    // the result reads like a normal paragraph of text, not a gappy list with
    // the bullets removed.
    private static final Pattern MD_BOLD = Pattern.compile("\\*\\*(.+?)\\*\\*|__(.+?)__");
    private static final Pattern MD_ITALIC = Pattern.compile("(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)");
    private static final Pattern MD_HEADER = Pattern.compile("(?m)^#{1,6}\\s*");
    private static final Pattern MD_BULLET = Pattern.compile("(?m)^\\s*[-*]\\s+");
    private static final Pattern MD_NUMBERED = Pattern.compile("(?m)^\\s*\\d+\\.\\s+");
    private static final Pattern EXTRA_BLANK_LINES = Pattern.compile("\n{3,}");

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