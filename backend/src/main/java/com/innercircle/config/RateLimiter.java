package com.innercircle.config;

import org.springframework.stereotype.Component;

import java.util.concurrent.ConcurrentHashMap;

/**
 * In-memory rate limiter for sensitive endpoints (password reset, login).
 * Tracks attempts per key (email or IP) with a sliding window.
 *
 * Production note: replace with Redis-backed limiter (e.g. bucket4j + Redis)
 * for multi-instance deployments. This single-node version is sufficient
 * for a single-instance Spring Boot app.
 */
@Component
public class RateLimiter {

    private final ConcurrentHashMap<String, AttemptRecord> attempts = new ConcurrentHashMap<>();

    private static final int MAX_RESET_ATTEMPTS = 5;
    private static final long RESET_WINDOW_MS = 15 * 60 * 1000; // 15 minutes
    private static final long LOCKOUT_DURATION_MS = 30 * 60 * 1000; // 30 minutes

    private static final int MAX_LOGIN_ATTEMPTS = 5;
    private static final long LOGIN_WINDOW_MS = 15 * 60 * 1000;

    /**
     * Returns true if the request should be allowed, false if rate-limited.
     */
    public boolean allowPasswordReset(String email) {
        return isAllowed(email, MAX_RESET_ATTEMPTS, RESET_WINDOW_MS);
    }

    public boolean allowLogin(String email) {
        return isAllowed("login:" + email, MAX_LOGIN_ATTEMPTS, LOGIN_WINDOW_MS);
    }

    public long getLockoutRemainingMs(String email) {
        AttemptRecord record = attempts.get("login:" + email);
        if (record == null) return 0;
        long elapsed = System.currentTimeMillis() - record.windowStart;
        if (elapsed > LOGIN_WINDOW_MS) return 0;
        if (record.count >= MAX_LOGIN_ATTEMPTS) {
            return LOCKOUT_DURATION_MS - elapsed;
        }
        return 0;
    }

    private boolean isAllowed(String key, int maxAttempts, long windowMs) {
        long now = System.currentTimeMillis();
        AttemptRecord record = attempts.compute(key, (k, existing) -> {
            if (existing == null || (now - existing.windowStart) > windowMs) {
                return new AttemptRecord(1, now);
            }
            existing.count++;
            return existing;
        });

        return record.count <= maxAttempts;
    }

    private static class AttemptRecord {
        int count;
        long windowStart;

        AttemptRecord(int count, long windowStart) {
            this.count = count;
            this.windowStart = windowStart;
        }
    }
}
