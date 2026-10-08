package com.innercircle.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Rate limiter for sensitive endpoints (password reset, login).
 *
 * Two backends, chosen automatically at startup:
 * - Redis (StringRedisTemplate): counters shared across instances.
 *   Activated when spring.data.redis.host is set (REDIS_HOST env).
 * - In-memory (ConcurrentHashMap): single-instance default. Zero
 *   infrastructure requirement.
 *
 * SECURITY: login attempts are only counted on failure — successful
 * logins reset the counter, so a legitimate user logging in from
 * multiple devices never self-locks. Stale entries are evicted to
 * bound memory usage.
 */
@Slf4j
@Component
public class RateLimiter {

    private final ConcurrentHashMap<String, AttemptRecord> attempts = new ConcurrentHashMap<>();
    private final StringRedisTemplate redis;
    private final boolean redisEnabled;

    // Injected optionally — if Redis host is not set, or the template
    // is not available, we fall back to the in-memory map.
    public RateLimiter(ObjectProvider<StringRedisTemplate> redisProvider,
                       @Value("${spring.data.redis.host:}") String redisHost) {
        StringRedisTemplate template = redisProvider.getIfAvailable();
        // Only enable Redis if the host is actually configured — the
        // template bean exists even with an empty host (Spring Boot
        // defaults to localhost), so we must check the property.
        this.redisEnabled = (template != null && redisHost != null && !redisHost.isBlank());
        this.redis = redisEnabled ? template : null;
        if (redisEnabled) {
            log.info("RateLimiter: using Redis backend at {} (distributed counters)", redisHost);
        } else {
            log.info("RateLimiter: using in-memory backend (single instance)");
        }
    }

    private static final int MAX_RESET_ATTEMPTS = 5;
    private static final Duration RESET_WINDOW = Duration.ofMinutes(15);

    private static final int MAX_LOGIN_ATTEMPTS = 5;
    private static final Duration LOGIN_WINDOW = Duration.ofMinutes(15);
    private static final Duration LOCKOUT_DURATION = Duration.ofMinutes(30);

    /**
     * Returns true if the password-reset request should be allowed (increments counter).
     */
    public boolean allowPasswordReset(String email) {
        if (redisEnabled) {
            return redisIsAllowed("reset:" + email, MAX_RESET_ATTEMPTS, RESET_WINDOW);
        }
        evictExpired();
        return isAllowed("reset:" + email, MAX_RESET_ATTEMPTS, RESET_WINDOW.toMillis());
    }

    /**
     * SECURITY: pre-check only — does NOT increment. Call recordLoginFailure
     * on failed auth and recordLoginSuccess on success.
     */
    public boolean isLoginAllowed(String email) {
        if (redisEnabled) {
            String key = "login:" + email;
            String val = redis.opsForValue().get(key);
            return val == null || Integer.parseInt(val) < MAX_LOGIN_ATTEMPTS;
        }
        evictExpired();
        AttemptRecord record = attempts.get("login:" + email);
        if (record == null) return true;
        long now = System.currentTimeMillis();
        if ((now - record.windowStart) > LOGIN_WINDOW.toMillis()) {
            attempts.remove("login:" + email);
            return true;
        }
        return record.count < MAX_LOGIN_ATTEMPTS;
    }

    public void recordLoginFailure(String email) {
        if (redisEnabled) {
            redisIsAllowed("login:" + email, MAX_LOGIN_ATTEMPTS, LOGIN_WINDOW);
            return;
        }
        evictExpired();
        isAllowed("login:" + email, MAX_LOGIN_ATTEMPTS, LOGIN_WINDOW.toMillis());
    }

    public void recordLoginSuccess(String email) {
        if (redisEnabled) {
            redis.delete("login:" + email);
            return;
        }
        attempts.remove("login:" + email);
    }

    public long getLockoutRemainingMs(String email) {
        if (redisEnabled) {
            Long ttl = redis.getExpire("login:" + email);
            if (ttl == null || ttl <= 0) return 0;
            String val = redis.opsForValue().get("login:" + email);
            if (val == null) return 0;
            return (Integer.parseInt(val) >= MAX_LOGIN_ATTEMPTS)
                    ? ttl * 1000
                    : 0;
        }
        AttemptRecord record = attempts.get("login:" + email);
        if (record == null) return 0;
        long elapsed = System.currentTimeMillis() - record.windowStart;
        if (elapsed > LOGIN_WINDOW.toMillis()) return 0;
        if (record.count >= MAX_LOGIN_ATTEMPTS) {
            return LOCKOUT_DURATION.toMillis() - elapsed;
        }
        return 0;
    }

    // ── Redis backend ──────────────────────────────────────────────

    private boolean redisIsAllowed(String key, int maxAttempts, Duration window) {
        Long count = redis.opsForValue().increment(key);
        if (count != null && count == 1L) {
            redis.expire(key, window);
        }
        return (count != null ? count : 0L) <= maxAttempts;
    }

    // ── In-memory backend ──────────────────────────────────────────

    private void evictExpired() {
        long now = System.currentTimeMillis();
        attempts.entrySet().removeIf(e -> (now - e.getValue().windowStart) > LOGIN_WINDOW.toMillis());
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
