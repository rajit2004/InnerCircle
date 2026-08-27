package com.innercircle.util;

import java.util.regex.Pattern;

/**
 * SECURITY: sanitizes user-supplied text before storing in the database.
 * Prevents XSS (if rendered in a browser context), SQL injection artifacts,
 * and other injection vectors. Applied at the service layer before persistence.
 */
public class InputSanitizer {

    private InputSanitizer() {}

    // Strip HTML tags
    private static final Pattern HTML_TAGS = Pattern.compile("<[^>]+>");
    // Strip null bytes
    private static final Pattern NULL_BYTES = Pattern.compile("\\x00");
    // Collapse multiple spaces
    private static final Pattern MULTI_SPACE = Pattern.compile(" {2,}");
    // Max display name length
    public static final int MAX_NAME_LENGTH = 100;
    // Max persona system prompt length
    public static final int MAX_PROMPT_LENGTH = 2000;
    // Max chat message length
    public static final int MAX_MESSAGE_LENGTH = 5000;

    /**
     * Sanitize a general text field (display name, persona name, etc.).
     * Strips HTML, null bytes, and trims whitespace.
     */
    public static String sanitizeText(String input) {
        if (input == null) return null;
        String result = input;
        result = NULL_BYTES.matcher(result).replaceAll("");
        result = HTML_TAGS.matcher(result).replaceAll("");
        result = result.trim();
        result = MULTI_SPACE.matcher(result).replaceAll(" ");
        if (result.length() > MAX_NAME_LENGTH) {
            result = result.substring(0, MAX_NAME_LENGTH);
        }
        return result;
    }

    /**
     * Sanitize a persona system prompt. Allows newlines but strips HTML.
     */
    public static String sanitizePrompt(String input) {
        if (input == null) return null;
        String result = input;
        result = NULL_BYTES.matcher(result).replaceAll("");
        result = HTML_TAGS.matcher(result).replaceAll("");
        result = result.trim();
        if (result.length() > MAX_PROMPT_LENGTH) {
            result = result.substring(0, MAX_PROMPT_LENGTH);
        }
        return result;
    }

    /**
     * Validate password strength. Returns null if valid, error message if not.
     */
    public static String validatePasswordStrength(String password) {
        if (password == null || password.length() < 8) {
            return "Password must be at least 8 characters";
        }
        if (password.length() > 128) {
            return "Password must be at most 128 characters";
        }
        boolean hasUpper = false;
        boolean hasLower = false;
        boolean hasDigit = false;
        for (char c : password.toCharArray()) {
            if (Character.isUpperCase(c)) hasUpper = true;
            else if (Character.isLowerCase(c)) hasLower = true;
            else if (Character.isDigit(c)) hasDigit = true;
        }
        if (!hasUpper || !hasLower || !hasDigit) {
            return "Password must contain uppercase, lowercase, and a number";
        }
        return null;
    }
}
