package com.innercircle.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.Set;
import java.util.regex.Pattern;

/**
 * Layer 5 of the 5-layer behavioral architecture.
 * Post-processes LLM responses to enforce naturalness and strip
 * AI-generated artifacts that break the illusion of human conversation.
 */
@Service
@Slf4j
public class NaturalnessFilter {

    // Phrases that immediately signal "AI assistant"
    private static final Set<String> AI_PHRASES = Set.of(
            "I understand",
            "I completely understand",
            "That makes complete sense",
            "Your feelings are valid",
            "It's understandable that you feel that way",
            "You're absolutely right",
            "I'm here for you",
            "I can help with that",
            "That's a great question",
            "Let me help you with that",
            "I appreciate you sharing",
            "Thank you for telling me",
            "That must be difficult",
            "I hear you",
            "Your feelings are completely valid",
            "It's okay to feel that way",
            "You're not alone in this",
            "I'm sorry you're going through this",
            "Would you like to talk about it",
            "How does that make you feel",
            "What do you think about that",
            "I'm here to listen",
            "Take your time",
            "There's no rush",
            "Take all the time you need"
    );

    // Patterns that indicate overly polished/formal text
    private static final Pattern FORMAL_PATTERN = Pattern.compile(
            "(?i)^(Furthermore|Moreover|Additionally|Consequently|Nevertheless|However|In conclusion|To summarize|First and foremost)"
    );

    // Pattern for therapy-speak
    private static final Pattern THERAPY_PATTERN = Pattern.compile(
            "(?i)(it'?s (completely |totally )?(okay|valid|understandable)|your feelings|I want you to know|I hear you|I see you)"
    );

    // Pattern for excessive emoji (more than 2)
    private static final Pattern EMOJI_FLOOD = Pattern.compile(
            "[\\x{1F600}-\\x{1F64F}\\x{1F300}-\\x{1F5FF}\\x{1F680}-\\x{1F6FF}\\x{1F900}-\\x{1F9FF}\\x{2600}-\\x{26FF}\\x{2700}-\\x{27BF}]{3,}"
    );

    // Pattern for double sentences (repeating the same idea)
    private static final Pattern REDUNDANT = Pattern.compile(
            "(?i)(I can tell (that )?|It sounds like (that )?|I (can )?tell (that )?)"
    );

    /**
     * Post-process a response to sound more natural and less AI-like.
     * Returns the cleaned response.
     */
    public String filter(String response, String personaRole) {
        if (response == null || response.isBlank()) return response;

        String result = response.trim();

        // Strip AI phrases
        for (String phrase : AI_PHRASES) {
            result = result.replaceAll("(?i)" + Pattern.quote(phrase), "");
        }

        // Strip therapy-speak
        result = THERAPY_PATTERN.matcher(result).replaceAll("");

        // Strip overly formal openers
        result = FORMAL_PATTERN.matcher(result).replaceAll("");

        // Strip redundant acknowledgment prefixes
        result = REDUNDANT.matcher(result).replaceAll("");

        // Limit emoji
        result = EMOJI_FLOOD.matcher(result).replaceAll("🎉");

        // Clean up double spaces and trailing/leading punctuation issues
        result = result.replaceAll("\\s{2,}", " ").trim();
        result = result.replaceAll("^[,;:!\\s]+", "").trim();
        result = result.replaceAll("[,;:!\\s]+$", "").trim();

        // Ensure response isn't empty after filtering
        if (result.isBlank()) {
            return response.trim();
        }

        return result;
    }
}
