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
            "Take all the time you need",
            "I want you to know",
            "I see you",
            "That's completely valid",
            "It makes total sense",
            "I totally get it",
            "You're not wrong",
            "I hear what you're saying",
            "That sounds really tough",
            "I'm always here",
            "Don't worry",
            "Everything will be okay",
            "You got this",
            "I believe in you",
            "That's amazing",
            "I'm so proud of you",
            "You deserve the best",
            "Never settle",
            "Know your worth",
            " Sending you love",
            "Sending hugs",
            "Stay strong",
            "You're stronger than you think",
            "This too shall pass",
            "What doesn't kill you makes you stronger"
    );

    // Patterns that indicate overly polished/formal text
    private static final Pattern FORMAL_PATTERN = Pattern.compile(
            "(?i)^(Furthermore|Moreover|Additionally|Consequently|Nevertheless|However|In conclusion|To summarize|First and foremost|It's important to note|It's worth mentioning)"
    );

    // Pattern for therapy-speak
    private static final Pattern THERAPY_PATTERN = Pattern.compile(
            "(?i)(it'?s (completely |totally )?(okay|valid|understandable)|your feelings|I want you to know|I hear you|I see you|I hear what you're saying|it makes (complete |total )?sense)"
    );

    // Pattern for excessive emoji (more than 2)
    private static final Pattern EMOJI_FLOOD = Pattern.compile(
            "[\\x{1F600}-\\x{1F64F}\\x{1F300}-\\x{1F5FF}\\x{1F680}-\\x{1F6FF}\\x{1F900}-\\x{1F9FF}\\x{2600}-\\x{26FF}\\x{2700}-\\x{27BF}]{3,}"
    );

    // Pattern for redundant acknowledgment prefixes
    private static final Pattern REDUNDANT = Pattern.compile(
            "(?i)(I can tell (that )?|It sounds like (that )?|I (can )?tell (that )?|I just want to say)"
    );

    // Pattern for em dashes (should not be used in casual texting)
    private static final Pattern EM_DASH = Pattern.compile("—");

    // Pattern for semicolons in casual texting (almost never natural)
    private static final Pattern SEMICOLON = Pattern.compile(";");

    // Pattern for double spaces
    private static final Pattern DOUBLE_SPACE = Pattern.compile("  +");

    // Pattern for leading/trailing punctuation artifacts
    private static final Pattern LEADING_PUNCT = Pattern.compile("^[,;:!\\s]+");
    private static final Pattern TRAILING_PUNCT = Pattern.compile("[,;:!\\s]+$");

    public String filter(String response, String personaRole) {
        if (response == null || response.isBlank()) return response;

        String original = response.trim();
        String result = original;

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

        // Replace em dashes with commas
        result = EM_DASH.matcher(result).replaceAll(",");

        // Remove semicolons (not natural in texting)
        result = SEMICOLON.matcher(result).replaceAll(",");

        // Limit emoji
        result = EMOJI_FLOOD.matcher(result).replaceAll("🎉");

        // Clean up
        result = DOUBLE_SPACE.matcher(result).replaceAll(" ");
        result = LEADING_PUNCT.matcher(result).replaceAll("");
        result = TRAILING_PUNCT.matcher(result).replaceAll("");
        result = result.trim();

        // Ensure response isn't empty after filtering
        if (result.isBlank()) {
            return original;
        }

        return result;
    }
}
