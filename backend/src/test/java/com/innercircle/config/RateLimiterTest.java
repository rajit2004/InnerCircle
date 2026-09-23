package com.innercircle.config;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class RateLimiterTest {

    private RateLimiter rateLimiter;

    @BeforeEach
    void setUp() {
        rateLimiter = new RateLimiter();
    }

    @Test
    void passwordResetAllowsUpToFiveAttempts() {
        for (int i = 0; i < 5; i++) {
            assertTrue(rateLimiter.allowPasswordReset("a@b.com"), "attempt " + i);
        }
        assertFalse(rateLimiter.allowPasswordReset("a@b.com"), "sixth attempt blocked");
    }

    @Test
    void successfulLoginResetsFailureCounter() {
        for (int i = 0; i < 5; i++) {
            rateLimiter.recordLoginFailure("a@b.com");
        }
        assertFalse(rateLimiter.isLoginAllowed("a@b.com"));

        rateLimiter.recordLoginSuccess("a@b.com");
        assertTrue(rateLimiter.isLoginAllowed("a@b.com"));
    }

    @Test
    void successfulLoginDoesNotCountTowardLimit() {
        // Successful logins alone must never lock an account out.
        for (int i = 0; i < 20; i++) {
            assertTrue(rateLimiter.isLoginAllowed("a@b.com"));
            rateLimiter.recordLoginSuccess("a@b.com");
        }
        assertTrue(rateLimiter.isLoginAllowed("a@b.com"));
    }

    @Test
    void fiveFailuresBlockSubsequentLogin() {
        for (int i = 0; i < 5; i++) {
            rateLimiter.recordLoginFailure("a@b.com");
        }
        assertFalse(rateLimiter.isLoginAllowed("a@b.com"));
    }

    @Test
    void differentEmailsAreIndependent() {
        for (int i = 0; i < 5; i++) {
            rateLimiter.recordLoginFailure("a@b.com");
        }
        assertFalse(rateLimiter.isLoginAllowed("a@b.com"));
        assertTrue(rateLimiter.isLoginAllowed("c@d.com"));
    }

    @Test
    void lockoutRemainingIsZeroBelowThreshold() {
        rateLimiter.recordLoginFailure("a@b.com");
        assertEquals(0, rateLimiter.getLockoutRemainingMs("a@b.com"));
    }

    @Test
    void lockoutRemainingIsPositiveAtThreshold() {
        for (int i = 0; i < 5; i++) {
            rateLimiter.recordLoginFailure("a@b.com");
        }
        assertTrue(rateLimiter.getLockoutRemainingMs("a@b.com") > 0);
    }
}
