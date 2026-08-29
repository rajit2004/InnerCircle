package com.innercircle.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Layer 1 of the 5-layer behavioral architecture.
 * Analyzes the user's message to understand intent, emotional state, and topic
 * before any response generation happens.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ConversationUnderstandingService {

    private final WebClient webClient;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Value("${groq.api-key}")
    private String groqApiKey;

    @Value("${groq.model}")
    private String groqModel;

    @Value("${groq.url}")
    private String groqUrl;

    /**
     * Analyzes the user message to determine intent, emotion, topic, and
     * response requirements. Returns a ConversationState that drives all
     * downstream decisions.
     */
    public ConversationState analyze(String userMessage, List<Map<String, String>> recentMessages) {
        String recentContext = recentMessages.stream()
                .skip(Math.max(0, recentMessages.size() - 6))
                .map(m -> m.get("role") + ": " + m.get("content"))
                .reduce((a, b) -> a + "\n" + b)
                .orElse("");

        String prompt = """
                Analyze this user message in the context of the recent conversation.
                Return ONLY a JSON object with these fields:

                {
                  "intent": "<one of: REACTION, QUESTION, VENTING, STORY, REQUEST, JOKE, GREETING, AFFECTION, EMOTIONAL_SUPPORT, SMALL_TALK, UPDATE, GOODBYE, CELEBRATION, COMPLAINT, REQUEST_AFFECTION>",
                  "emotion": "<primary emotion: happy, sad, anxious, excited, frustrated, angry, tired, stressed, playful, romantic, neutral, surprised, grateful, bored, lonely, proud, embarrassed>",
                  "emotional_intensity": "<one of: low, medium, high>",
                  "topic": "<brief description of what they're talking about>",
                  "needs_response": true,
                  "is_question": <true if asking a question>,
                  "is_short_form": <true if message is very short like "lol", "ok", "ugh", "❤️">,
                  "response_length_hint": "<one of: very_short, short, medium, long> - what length response feels natural for THIS message",
                  "requires_emotional_response": <true if they need emotional validation/support>,
                  "should_ask_followup": <true if a follow-up question would feel natural>,
                  "user_energy": "<one of: high, medium, low> - match their conversational energy"
                }

                Recent conversation:
                %s

                Current message: %s

                Output only the JSON:
                """.formatted(recentContext, userMessage);

        try {
            Map<String, Object> body = new HashMap<>();
            body.put("model", groqModel);
            body.put("messages", List.of(Map.of("role", "user", "content", prompt)));
            body.put("temperature", 0.2);
            body.put("max_tokens", 300);

            String response = webClient.post()
                    .uri(groqUrl)
                    .header("Authorization", "Bearer " + groqApiKey)
                    .bodyValue(body)
                    .retrieve()
                    .bodyToMono(String.class)
                    .block();

            if (response == null) return defaultState(userMessage);

            JsonNode root = objectMapper.readTree(response);
            String content = root.path("choices").get(0).path("message").path("content").asText("{}");

            String cleanContent = content.trim();
            if (cleanContent.startsWith("```")) {
                cleanContent = cleanContent.replaceAll("(?s)^```[a-zA-Z]*\\n?", "").replaceAll("```\\s*$", "").trim();
            }

            // If the response is truncated (no closing brace), try to salvage it
            if (!cleanContent.endsWith("}")) {
                int lastBrace = cleanContent.lastIndexOf('}');
                if (lastBrace > 0) {
                    cleanContent = cleanContent.substring(0, lastBrace + 1);
                }
            }

            JsonNode stateNode = objectMapper.readTree(cleanContent);
            return ConversationState.builder()
                    .intent(stateNode.path("intent").asText("REACTION"))
                    .emotion(stateNode.path("emotion").asText("neutral"))
                    .emotionalIntensity(stateNode.path("emotional_intensity").asText("low"))
                    .topic(stateNode.path("topic").asText(""))
                    .needsResponse(stateNode.path("needs_response").asBoolean(true))
                    .isQuestion(stateNode.path("is_question").asBoolean(false))
                    .isShortForm(stateNode.path("is_short_form").asBoolean(false))
                    .responseLengthHint(stateNode.path("response_length_hint").asText("short"))
                    .requiresEmotionalResponse(stateNode.path("requires_emotional_response").asBoolean(false))
                    .shouldAskFollowup(stateNode.path("should_ask_followup").asBoolean(false))
                    .userEnergy(stateNode.path("user_energy").asText("medium"))
                    .build();

        } catch (Exception e) {
            log.warn("Conversation understanding failed, using defaults: {}", e.getMessage());
            return defaultState(userMessage);
        }
    }

    private ConversationState defaultState(String message) {
        String trimmed = message.trim();
        boolean isShort = trimmed.length() <= 5;
        return ConversationState.builder()
                .intent("REACTION")
                .emotion("neutral")
                .emotionalIntensity("low")
                .topic("")
                .needsResponse(true)
                .isQuestion(trimmed.endsWith("?"))
                .isShortForm(isShort)
                .responseLengthHint(isShort ? "very_short" : "short")
                .requiresEmotionalResponse(false)
                .shouldAskFollowup(false)
                .userEnergy("medium")
                .build();
    }

    @lombok.Builder
    @lombok.Data
    public static class ConversationState {
        private String intent;
        private String emotion;
        private String emotionalIntensity;
        private String topic;
        private boolean needsResponse;
        private boolean isQuestion;
        private boolean isShortForm;
        private String responseLengthHint;
        private boolean requiresEmotionalResponse;
        private boolean shouldAskFollowup;
        private String userEnergy;
    }
}
