package src.main.java.com.innercircle.service;

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

@Service
@RequiredArgsConstructor
@Slf4j
public class MemoryService {

    private static final int MAX_RELEVANT_MEMORIES = 5;

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
     * existed, or if embedding generation ever fails).
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
        return memoryRepository.findByUserAndPersonaOrderByImportanceDesc(user, persona)
                .stream()
                .limit(MAX_RELEVANT_MEMORIES)
                .toList();
    }

    @Transactional
    public void extractAndStoreMemory(User user, String personaId, String userMessage, String assistantReply) {
        try {
            Persona persona = personaId != null ? personaRepository.findById(UUID.fromString(personaId)).orElse(null) : null;
            List<Memory> existing = memoryRepository.findByUserAndPersonaOrderByImportanceDesc(user, persona);
            String existingFacts = existing.stream()
                    .map(Memory::getFact)
                    .reduce((a, b) -> a + "\n" + b)
                    .orElse("");

            String prompt = """
                    Extract 1-3 important facts about the user from this conversation.
                    Return as JSON array of strings.
                    Only extract lasting information (preferences, life events, relationships, goals).
                    If no new facts, return [].

                    Existing facts about the user:
                    %s

                    User: %s
                    Assistant: %s

                    Output only JSON array:
                    """.formatted(existingFacts, userMessage, assistantReply);

            Map<String, Object> body = new HashMap<>();
            body.put("model", groqModel);
            body.put("messages", List.of(Map.of("role", "user", "content", prompt)));
            body.put("temperature", 0.3);
            body.put("max_tokens", 150);

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

            String[] facts = objectMapper.readValue(cleanContent, String[].class);

            for (String fact : facts) {
                if (fact == null || fact.isBlank()) continue;

                float[] vector = embeddingService.embed(fact);

                Memory memory = new Memory();
                memory.setUser(user);
                memory.setPersona(persona);
                memory.setFact(fact);
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
