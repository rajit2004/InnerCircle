package com.innercircle.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.innercircle.model.Memory;
import com.innercircle.model.Persona;
import com.innercircle.model.User;
import com.innercircle.repository.MemoryRepository;
import com.innercircle.repository.PersonaRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.reactive.function.client.WebClient;

import java.time.Instant;
import java.util.*;
import java.util.regex.Pattern;

@Service
@RequiredArgsConstructor
@Slf4j
public class MemoryService {

    private static final int MAX_RELEVANT_MEMORIES = 5;

    // FEATURE (shared memory, 2026-07-02): Safety net for detecting relay
    // intent even if the LLM's own "shared": true/false classification (see
    // the extraction prompt below) misses it. Catches phrasing like
    // "tell mom", "let my sister know", "share this with everyone", etc.
    // This is intentionally a coarse net, not a precise parser -- false
    // positives (marking something shared that maybe should've stayed
    // private) are far less harmful here than false negatives (a relay
    // request silently going nowhere, which was the original bug).
    private static final Pattern RELAY_INTENT_PATTERN = Pattern.compile(
            "(?i)\\b(tell|let|inform|pass (this|that|it)? (on|along)? to|share (this|that|it)? with)\\b"
    );

    private final WebClient webClient;
    private final MemoryRepository memoryRepository;
    private final PersonaRepository personaRepository;
    private final EmbeddingService embeddingService;

    @Value("${groq.api-key}")
    private String groqApiKey;

    @Value("${groq.model}")
    private String groqModel;

    @Value("${groq.url}")
    private String groqUrl;

    private final ObjectMapper objectMapper = new ObjectMapper();

    /**
     * Retrieve the memories most relevant to the current message via pgvector
     * cosine similarity, falling back to importance-ranked memories for users
     * who don't have any embedded memories yet (e.g. ones created before this
     * existed, or if embedding generation ever fails). Both paths now include
     * memories marked shared = true regardless of which persona they were
     * originally extracted under -- see MemoryRepository for the query changes.
     */
    public List<Memory> findRelevantMemories(User user, UUID personaId, String currentMessage) {
        float[] queryVector = embeddingService.embed(currentMessage);
        String literal = embeddingService.toPgVectorLiteral(queryVector);

        List<Memory> relevant = memoryRepository.findRelevantMemories(
                user.getId(), personaId, literal, MAX_RELEVANT_MEMORIES);

        if (!relevant.isEmpty()) {
            return relevant;
        }

        Persona persona = personaId != null ? personaRepository.findById(personaId).orElse(null) : null;
        if (persona == null) {
            return memoryRepository.findByUserOrderByImportanceDesc(user)
                    .stream()
                    .limit(MAX_RELEVANT_MEMORIES)
                    .toList();
        }
        return memoryRepository.findByUserAndPersonaOrSharedOrderByImportanceDesc(user, persona)
                .stream()
                .limit(MAX_RELEVANT_MEMORIES)
                .toList();
    }

    @Transactional
    public void extractAndStoreMemory(User user, String personaId, String userMessage, String assistantReply) {
        try {
            Persona persona = personaId != null ? personaRepository.findById(UUID.fromString(personaId)).orElse(null) : null;

            List<Memory> existing = persona != null
                    ? memoryRepository.findByUserAndPersonaOrSharedOrderByImportanceDesc(user, persona)
                    : memoryRepository.findByUserOrderByImportanceDesc(user);
            String existingFacts = existing.stream()
                    .map(Memory::getFact)
                    .reduce((a, b) -> a + "\n" + b)
                    .orElse("");

            // FEATURE (shared memory, 2026-07-02): Prompt now asks the model to
            // classify each fact as shared or not, instead of returning plain
            // strings. "shared": true means this fact should be visible to
            // every persona, not just the one it was said to -- reserved for
            // cases where the user is explicitly asking to relay/pass along
            // information (e.g. "tell mom I want a hamburger"), not just
            // sharing something personal in the normal course of conversation.
            String prompt = """
                    Extract 1-3 important facts about the user from this conversation.
                    Return as a JSON array of objects, each with a "fact" and a "shared" field:
                    [{"fact": "...", "shared": true}, {"fact": "...", "shared": false}]

                    Only extract lasting information (preferences, life events, relationships, goals).

                    Set "shared": true ONLY if the user is explicitly asking to relay, tell, pass
                    along, or share this specific piece of information with another persona or
                    person (e.g. "tell mom I want a hamburger", "let my sister know I got the job",
                    "share this with everyone"). Set "shared": false for everything else -- most
                    facts are ordinary personal details said in the normal course of conversation
                    and should stay private to this persona.

                    If no new facts, return [].

                    Existing facts about the user:
                    %s

                    User: %s
                    Assistant: %s

                    Output only the JSON array:
                    """.formatted(existingFacts, userMessage, assistantReply);

            Map<String, Object> body = new HashMap<>();
            body.put("model", groqModel);
            body.put("messages", List.of(Map.of("role", "user", "content", prompt)));
            body.put("temperature", 0.3);
            body.put("max_tokens", 200);

            String response = webClient.post()
                    .uri(groqUrl)
                    .header("Authorization", "Bearer " + groqApiKey)
                    .bodyValue(body)
                    .retrieve()
                    .bodyToMono(String.class)
                    .block();

            if (response == null) return;

            JsonNode root = objectMapper.readTree(response);
            String content = root.path("choices").get(0).path("message").path("content").asText("[]");

            // LLMs sometimes wrap JSON in markdown code fences despite instructions -- strip if present.
            String cleanContent = content.trim();
            if (cleanContent.startsWith("```")) {
                cleanContent = cleanContent.replaceAll("(?s)^```[a-zA-Z]*\\n?", "").replaceAll("```\\s*$", "").trim();
            }

            if (cleanContent.isEmpty() || cleanContent.equals("[]")) {
                return;
            }

            // Regex safety net: if the user's own message reads like a relay
            // request, force shared = true on everything extracted from this
            // turn even if the LLM's classification missed it. False positives
            // here are cheap (a fact becomes visible to other personas that
            // maybe didn't need to be); false negatives are the original bug
            // (a relay request silently going nowhere).
            boolean relayIntentDetected = RELAY_INTENT_PATTERN.matcher(userMessage).find();

            JsonNode factsNode = objectMapper.readTree(cleanContent);
            if (!factsNode.isArray()) return;

            for (JsonNode node : factsNode) {
                String fact;
                boolean shared;

                if (node.isObject()) {
                    fact = node.path("fact").asText("").trim();
                    shared = node.path("shared").asBoolean(false);
                } else if (node.isTextual()) {
                    // Defensive fallback in case the model ignores the object-array
                    // instruction and reverts to the old plain-string-array shape.
                    fact = node.asText("").trim();
                    shared = false;
                } else {
                    continue;
                }

                if (fact.isBlank()) continue;
                if (relayIntentDetected) shared = true;

                float[] vector = embeddingService.embed(fact);

                Memory memory = new Memory();
                memory.setUser(user);
                memory.setPersona(persona);
                memory.setFact(fact);
                memory.setShared(shared);
                memory.setEmbedding(embeddingService.toPgVectorLiteral(vector));
                memory.setImportance(1);
                memory.setLastAccessed(Instant.now());
                memoryRepository.save(memory);
            }
        } catch (Exception e) {
            // Memory extraction is best-effort -- never let it break the chat response.
            log.warn("Memory extraction failed: {}", e.getMessage());
        }
    }
}