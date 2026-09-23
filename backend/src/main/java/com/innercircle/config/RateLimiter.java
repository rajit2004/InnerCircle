package com.innercircle.config;

import org.springframework.stereotype.Component;

import java.util.concurrent.ConcurrentHashMap;

/**
 * In-memory rate limiter for sensitive endpoints (password reset, login).
 * Tracks attempts per key (email or IP) with a sliding window.
 *
 * SECURITY: login attempts are only counted on failure — successful logins
 * reset the counter, so a legitimate user logging in from multiple devices
 * never self-locks. Stale entries are evicted to bound memory usage.
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
     * Returns true if the password-reset request should be allowed (increments counter).
     */
    public boolean allowPasswordReset(String email) {
        evictExpired();
        return isAllowed(email, MAX_RESET_ATTEMPTS, RESET_WINDOW_MS);
    }

    /**
     * SECURITY: pre-check only — does NOT increment. Call recordLoginFailure
     * on failed auth and recordLoginSuccess on success.
     */
    public boolean isLoginAllowed(String email) {
        evictExpired();
        String key = "login:" + email;
        AttemptRecord record = attempts.get(key);
        if (record == null) return true;
        long now = System.currentTimeMillis();
        if ((now - record.windowStart) > LOGIN_WINDOW_MS) {
            attempts.remove(key);
            return true;
        }
        return record.count < MAX_LOGIN_ATTEMPTS;
    }

    public void recordLoginFailure(String email) {
        evictExpired();
        isAllowed("login:" + email, MAX_LOGIN_ATTEMPTS, LOGIN_WINDOW_MS);
    }

    public void recordLoginSuccess(String email) {
        attempts.remove("login:" + email);
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

    /**
     * SECURITY: remove entries whose window has fully elapsed so the map
     * cannot grow without bound under key-spraying attacks.
     */
    private void evictExpired() {
        long now = System.currentTimeMillis();
        attempts.entrySet().removeIf(e -> (now - e.getValue().windowStart) > LOGIN_WINDOW_MS);
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
