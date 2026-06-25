package com.innercircle.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.innercircle.model.Memory;
import com.innercircle.model.Persona;
import com.innercircle.model.User;
import com.innercircle.repository.MemoryRepository;
import com.innercircle.repository.PersonaRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.reactive.function.client.WebClient;

import java.util.*;

@Service
@RequiredArgsConstructor
public class MemoryService {

    private final WebClient webClient;
    private final MemoryRepository memoryRepository;
    private final PersonaRepository personaRepository;

    @Value("${groq.api-key}")
    private String groqApiKey;

    @Value("${groq.model}")
    private String groqModel;

    @Value("${groq.url}")
    private String groqUrl;

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Transactional
    public void extractAndStoreMemory(User user, String personaId, String userMessage, String assistantReply) {
        try {
            Persona persona = personaRepository.findById(UUID.fromString(personaId)).orElse(null);
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

            if (response != null) {
                JsonNode root = objectMapper.readTree(response);
                String content = root.path("choices").get(0).path("message").path("content").asText("[]");

                // BUG FIX: The original code did objectMapper.readValue(content, String[].class)
                // which throws JsonParseException when the LLM wraps the JSON in markdown
                // code fences (```json ... ```) — a very common LLM behaviour.
                // Fix: strip any markdown code-fence wrapper before parsing.
                String cleanContent = content.trim();
                if (cleanContent.startsWith("```")) {
                    cleanContent = cleanContent.replaceAll("(?s)^```[a-zA-Z]*\\n?", "").replaceAll("```\\s*$", "").trim();
                }

                // BUG FIX 2: If the LLM returns an empty array or whitespace,
                // the original code would still try to iterate and save — harmless,
                // but let's guard against non-array JSON just in case.
                if (cleanContent.isEmpty() || cleanContent.equals("[]")) {
                    return;
                }

                String[] facts = objectMapper.readValue(cleanContent, String[].class);

                for (String fact : facts) {
                    if (fact == null || fact.isBlank()) continue; // skip empty facts
                    Memory memory = new Memory();
                    memory.setUser(user);
                    memory.setPersona(persona);
                    memory.setFact(fact);
                    memory.setImportance(1);
                    memoryRepository.save(memory);
                }
            }
        } catch (Exception e) {
            System.err.println("Memory extraction error: " + e.getMessage());
        }
    }
}
