package com.innercircle.service;

import com.innercircle.model.Persona;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.Map;

/**
 * Layer 3 of the 5-layer behavioral architecture.
 * Determines the response strategy based on conversation state, relationship,
 * and persona. This drives how the LLM should respond without bloating the
 * system prompt.
 */
@Service
@Slf4j
public class ResponseStrategyService {

    /**
     * Determines the response strategy given all available context.
     * Returns a strategy object that gets injected into the prompt.
     */
    public ResponseStrategy determine(
            ConversationUnderstandingService.ConversationState state,
            String relationshipStage,
            Persona persona) {

        ResponseStrategy strategy = new ResponseStrategy();

        // Base strategy from intent
        strategy.setShouldReact(true);
        strategy.setShouldAdvise(false);
        strategy.setShouldQuestion(false);
        strategy.setShouldTease(false);
        strategy.setShouldDisagree(false);
        strategy.setShouldValidate(false);
        strategy.setShouldMatchEnergy(true);

        String intent = state.getIntent() != null ? state.getIntent() : "REACTION";

        switch (intent) {
            case "CELEBRATION" -> {
                strategy.setResponseTone("excited");
                strategy.setShouldValidate(true);
                strategy.setShouldQuestion(false);
            }
            case "VENTING", "COMPLAINT" -> {
                strategy.setResponseTone("empathetic");
                strategy.setShouldReact(true);
                strategy.setShouldAdvise(false);
                strategy.setShouldValidate(true);
            }
            case "EMOTIONAL_SUPPORT" -> {
                strategy.setResponseTone("warm");
                strategy.setShouldValidate(true);
                strategy.setShouldQuestion(state.isShouldAskFollowup());
            }
            case "QUESTION" -> {
                strategy.setResponseTone("helpful");
                strategy.setShouldAdvise(true);
                strategy.setShouldQuestion(false);
            }
            case "JOKE" -> {
                strategy.setResponseTone("playful");
                strategy.setShouldTease(true);
            }
            case "GREETING" -> {
                strategy.setResponseTone("warm");
                strategy.setShouldQuestion(true);
            }
            case "AFFECTION", "REQUEST_AFFECTION" -> {
                strategy.setResponseTone("affectionate");
                strategy.setShouldValidate(true);
            }
            case "STORY", "UPDATE" -> {
                strategy.setResponseTone("interested");
                strategy.setShouldQuestion(state.isShouldAskFollowup());
            }
            case "SMALL_TALK" -> {
                strategy.setResponseTone("casual");
                strategy.setShouldQuestion(state.isShouldAskFollowup());
            }
            case "GOODBYE" -> {
                strategy.setResponseTone("warm");
                strategy.setShouldReact(true);
            }
            default -> strategy.setResponseTone("natural");
        }

        // Adjust for relationship stage
        if ("new".equals(relationshipStage)) {
            strategy.setShouldTease(false);
            strategy.setShouldDisagree(false);
            // Don't be overly familiar early on
        } else if ("established".equals(relationshipStage) || "deep".equals(relationshipStage)) {
            // Can be more playful and direct
            if ("BEST_FRIEND".equals(persona.getRole())) {
                strategy.setShouldTease(true);
            }
        }

        // Adjust for emotional state
        if (state.isRequiresEmotionalResponse()) {
            strategy.setShouldAdvise(false);
            strategy.setShouldValidate(true);
        }

        // Response length
        strategy.setIdealLength(mapLengthHint(state));

        return strategy;
    }

    private String mapLengthHint(ConversationUnderstandingService.ConversationState state) {
        if (state.isShortForm()) return "very_short";
        return state.getResponseLengthHint();
    }

    @lombok.Data
    public static class ResponseStrategy {
        private String responseTone = "natural";
        private boolean shouldReact = true;
        private boolean shouldAdvise = false;
        private boolean shouldQuestion = false;
        private boolean shouldTease = false;
        private boolean shouldDisagree = false;
        private boolean shouldValidate = false;
        private boolean shouldMatchEnergy = true;
        private String idealLength = "short";

        /**
         * Build a concise strategy block for injection into the prompt.
         */
        public String toPromptBlock() {
            StringBuilder sb = new StringBuilder();
            sb.append("RESPONSE STRATEGY:\n");
            sb.append("Tone: ").append(responseTone).append("\n");
            sb.append("Ideal length: ").append(idealLength).append("\n");

            if (shouldReact) sb.append("- React to what they said first\n");
            if (shouldAdvise) sb.append("- They're asking for input, give a genuine response\n");
            if (shouldQuestion) sb.append("- A follow-up question would feel natural\n");
            if (shouldTease) sb.append("- Playful teasing is appropriate here\n");
            if (shouldDisagree) sb.append("- You can disagree if it feels genuine\n");
            if (shouldValidate) sb.append("- Acknowledge their feelings\n");
            if (shouldMatchEnergy) sb.append("- Match their energy level\n");

            return sb.toString();
        }
    }
}
