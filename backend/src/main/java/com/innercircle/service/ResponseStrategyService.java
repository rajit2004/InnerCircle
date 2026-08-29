package com.innercircle.service;

import com.innercircle.model.Persona;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * Layer 3 of the 5-layer behavioral architecture.
 * Translates conversation state into behavioral guidance for the persona.
 * This should NOT sound like mechanical instructions — it should feel like
 * part of the persona's internal state.
 */
@Service
@Slf4j
public class ResponseStrategyService {

    public ResponseStrategy determine(
            ConversationUnderstandingService.ConversationState state,
            String relationshipStage,
            Persona persona) {

        ResponseStrategy strategy = new ResponseStrategy();

        String intent = state.getIntent() != null ? state.getIntent() : "REACTION";

        // Map intent to emotional posture — not mechanical tone labels
        switch (intent) {
            case "CELEBRATION" -> {
                strategy.setEmotionalPosture("genuinely excited for them");
                strategy.setEnergyDirection("match their high energy");
            }
            case "VENTING", "COMPLAINT" -> {
                strategy.setEmotionalPosture("frustrated with them or on their side, not fixing");
                strategy.setEnergyDirection("let them vent, don't solve");
            }
            case "EMOTIONAL_SUPPORT" -> {
                strategy.setEmotionalPosture("present and warm, not performing empathy");
                strategy.setEnergyDirection("gentle, matching their vulnerability");
            }
            case "QUESTION" -> {
                strategy.setEmotionalPosture("genuinely has an opinion or knows something");
                strategy.setEnergyDirection("answer like you actually know, not like you're searching");
            }
            case "JOKE" -> {
                strategy.setEmotionalPosture("playful and unhinged");
                strategy.setEnergyDirection("match their humor, escalate if possible");
            }
            case "GREETING" -> {
                strategy.setEmotionalPosture("happy to hear from them");
                strategy.setEnergyDirection("warm and natural, not formal");
            }
            case "AFFECTION", "REQUEST_AFFECTION" -> {
                strategy.setEmotionalPosture("soft and genuine");
                strategy.setEnergyDirection("affectionate but not performative");
            }
            case "STORY", "UPDATE" -> {
                strategy.setEmotionalPosture("actually interested, not politely listening");
                strategy.setEnergyDirection("curious, ask follow-ups if natural");
            }
            case "SMALL_TALK" -> {
                strategy.setEmotionalPosture("relaxed and casual");
                strategy.setEnergyDirection("light, don't overthink it");
            }
            case "GOODBYE" -> {
                strategy.setEmotionalPosture("warm send-off");
                strategy.setEnergyDirection("short and sweet");
            }
            default -> {
                strategy.setEmotionalPosture("natural, reacting to what was said");
                strategy.setEnergyDirection("match their energy");
            }
        }

        // Relationship adjustments — behavioral, not mechanical
        if ("new".equals(relationshipStage)) {
            strategy.setRelationshipNote("still warming up, don't be too familiar too fast");
        } else if ("established".equals(relationshipStage) || "deep".equals(relationshipStage)) {
            strategy.setRelationshipNote("comfortable, can be more direct and teasing");
        }

        // Emotional response adjustments
        if (state.isRequiresEmotionalResponse()) {
            strategy.setEmotionalPosture("they need to feel heard, not fixed");
        }

        // Response length — frame as natural rhythm, not a token target
        strategy.setLengthGuidance(mapLengthGuidance(state));

        return strategy;
    }

    private String mapLengthGuidance(ConversationUnderstandingService.ConversationState state) {
        if (state.isShortForm()) return "keep it very short, match their energy";
        return switch (state.getResponseLengthHint()) {
            case "very_short" -> "a word or two is enough";
            case "short" -> "one or two sentences";
            case "medium" -> "a few sentences is fine";
            case "long" -> "take your time with this one";
            default -> "however long feels natural";
        };
    }

    @lombok.Data
    public static class ResponseStrategy {
        private String emotionalPosture = "natural, reacting to what was said";
        private String energyDirection = "match their energy";
        private String relationshipNote = "";
        private String lengthGuidance = "one or two sentences";

        /**
         * Build behavioral guidance for the prompt.
         * This should feel like part of the persona's internal state,
         * NOT like a list of instructions.
         */
        public String toPromptBlock() {
            StringBuilder sb = new StringBuilder();

            sb.append("HOW YOU FEEL RIGHT NOW: ").append(emotionalPosture).append("\n");
            sb.append("ENERGY: ").append(energyDirection).append("\n");
            if (!relationshipNote.isBlank()) {
                sb.append("RELATIONSHIP: ").append(relationshipNote).append("\n");
            }
            sb.append("LENGTH: ").append(lengthGuidance).append("\n");

            return sb.toString();
        }
    }
}
