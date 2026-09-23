package com.innercircle.util;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class InputSanitizerTest {

    @Test
    void sanitizeTextStripsHtmlAndNullBytes() {
        // Only the tags are removed; tag *content* (alert(1)) remains —
        // that is expected for plain-text storage (no HTML renderer).
        assertEquals("Hello alert(1) script",
                InputSanitizer.sanitizeText("Hello <script>alert(1)</script> script"));
        assertEquals("ab", InputSanitizer.sanitizeText("a\u0000b"));
    }

    @Test
    void sanitizeTextTrimsAndCollapsesSpaces() {
        assertEquals("a b", InputSanitizer.sanitizeText("  a   b  "));
    }

    @Test
    void sanitizeTextTruncatesToMaxNameLength() {
        String longName = "x".repeat(150);
        assertEquals(InputSanitizer.MAX_NAME_LENGTH, InputSanitizer.sanitizeText(longName).length());
    }

    @Test
    void sanitizeTextWithExplicitLengthDoesNotCapAt100() {
        String desc = "y".repeat(250);
        assertEquals(250, InputSanitizer.sanitizeText(desc, 300).length());
        assertEquals(200, InputSanitizer.sanitizeText(desc, 200).length());
    }

    @Test
    void sanitizeTextNullReturnsNull() {
        assertNull(InputSanitizer.sanitizeText(null));
    }

    @Test
    void sanitizePromptAllowsNewlinesButStripsHtml() {
        String result = InputSanitizer.sanitizePrompt("line1\nline2 <b>bold</b>");
        assertEquals("line1\nline2 bold", result);
    }

    @Test
    void passwordStrengthRejectsShortPasswords() {
        assertNotNull(InputSanitizer.validatePasswordStrength(null));
        assertNotNull(InputSanitizer.validatePasswordStrength("Ab1"));
        assertEquals("Password must be at least 8 characters",
                InputSanitizer.validatePasswordStrength("Ab1"));
    }

    @Test
    void passwordStrengthRequiresUpperLowerDigit() {
        assertNotNull(InputSanitizer.validatePasswordStrength("alllowercase"));
        assertNotNull(InputSanitizer.validatePasswordStrength("ALLUPPERCASE1"));
        assertNotNull(InputSanitizer.validatePasswordStrength("12345678"));
        assertNotNull(InputSanitizer.validatePasswordStrength("Abcdefgh"));
    }

    @Test
    void passwordStrengthAcceptsValidPassword() {
        assertNull(InputSanitizer.validatePasswordStrength("Passw0rd"));
    }
}
