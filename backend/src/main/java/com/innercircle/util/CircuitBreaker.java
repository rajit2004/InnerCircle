package com.innercircle.util;

import lombok.extern.slf4j.Slf4j;

import java.time.Duration;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.Supplier;

/**
 * Lightweight circuit breaker for external API calls (Groq).
 *
 * Three states:
 * - CLOSED:   normal operation, failures are counted
 * - OPEN:     calls are rejected immediately (fail fast) for cooldownDuration
 * - HALF_OPEN: one trial call is allowed; success closes, failure re-opens
 *
 * Implemented inline instead of pulling in Resilience4j to keep the
 * dependency tree minimal — the total surface used here is ~100 lines
 * versus a full library. Swap for Resilience4j if we ever need bulkheads
 * or rate limiters alongside breakers.
 */
@Slf4j
public final class CircuitBreaker {

    public enum State { CLOSED, OPEN, HALF_OPEN }

    private final String name;
    private final int failureThreshold;
    private final Duration cooldownDuration;
    private final Duration halfOpenTimeout;

    private final AtomicReference<State> state = new AtomicReference<>(State.CLOSED);
    private final AtomicInteger consecutiveFailures = new AtomicInteger();
    private final AtomicLong openedAt = new AtomicLong();
    private final AtomicLong lastHalfOpenAttempt = new AtomicLong();

    // Optional metrics hook — set by the caller (e.g. MetricsConfig).
    private volatile Runnable onStateChange;

    public CircuitBreaker(String name, int failureThreshold,
                          Duration cooldownDuration, Duration halfOpenTimeout) {
        this.name = name;
        this.failureThreshold = failureThreshold;
        this.cooldownDuration = cooldownDuration;
        this.halfOpenTimeout = halfOpenTimeout;
    }

    /**
     * Executes the operation through the circuit breaker.
     *
     * @throws CircuitOpenException if the breaker is OPEN
     */
    public <T> T execute(Supplier<T> operation) {
        if (!tryAcquirePermission()) {
            throw new CircuitOpenException(name);
        }

        try {
            T result = operation.get();
            onSuccess();
            return result;
        } catch (CircuitOpenException e) {
            throw e;
        } catch (RuntimeException e) {
            onFailure(e);
            throw e;
        }
    }

    private synchronized boolean tryAcquirePermission() {
        State current = state.get();
        switch (current) {
            case CLOSED:
                return true;
            case OPEN:
                long elapsed = System.currentTimeMillis() - openedAt.get();
                if (elapsed >= cooldownDuration.toMillis()) {
                    state.set(State.HALF_OPEN);
                    lastHalfOpenAttempt.set(System.currentTimeMillis());
                    log.info("Circuit breaker [{}] transitioning OPEN -> HALF_OPEN", name);
                    notifyStateChange();
                    return true;
                }
                return false;
            case HALF_OPEN:
                // Only allow one trial call at a time during half-open.
                long sinceAttempt = System.currentTimeMillis() - lastHalfOpenAttempt.get();
                if (sinceAttempt >= halfOpenTimeout.toMillis()) {
                    lastHalfOpenAttempt.set(System.currentTimeMillis());
                    return true;
                }
                return false;
            default:
                return false;
        }
    }

    private synchronized void onSuccess() {
        State current = state.get();
        if (current == State.HALF_OPEN) {
            state.set(State.CLOSED);
            consecutiveFailures.set(0);
            log.info("Circuit breaker [{}] HALF_OPEN -> CLOSED (recovered)", name);
            notifyStateChange();
        } else if (current == State.CLOSED) {
            consecutiveFailures.set(0);
        }
    }

    private synchronized void onFailure(RuntimeException e) {
        int failures = consecutiveFailures.incrementAndGet();
        State current = state.get();

        if (current == State.HALF_OPEN) {
            tripOpen();
            log.warn("Circuit breaker [{}] HALF_OPEN -> OPEN (trial call failed): {}",
                    name, e.getMessage());
        } else if (current == State.CLOSED && failures >= failureThreshold) {
            tripOpen();
            log.warn("Circuit breaker [{}] CLOSED -> OPEN after {} consecutive failures: {}",
                    name, failures, e.getMessage());
        } else if (current == State.CLOSED) {
            log.debug("Circuit breaker [{}] failure {}/{}: {}",
                    name, failures, failureThreshold, e.getMessage());
        }
    }

    private void tripOpen() {
        state.set(State.OPEN);
        openedAt.set(System.currentTimeMillis());
        consecutiveFailures.set(0);
        notifyStateChange();
    }

    private void notifyStateChange() {
        Runnable hook = onStateChange;
        if (hook != null) {
            try {
                hook.run();
            } catch (Exception ignored) {
                // Metrics hook must never break the request path.
            }
        }
    }

    public State getState() {
        return state.get();
    }

    public void setOnStateChange(Runnable hook) {
        this.onStateChange = hook;
    }

    /**
     * Thrown when the circuit is OPEN and the call is short-circuited.
     * Callers should treat this as "external service unavailable" and
     * fall back to a cached/default response.
     */
    public static class CircuitOpenException extends RuntimeException {
        public CircuitOpenException(String breakerName) {
            super("Circuit breaker [" + breakerName + "] is OPEN — short-circuiting call");
        }
    }
}
