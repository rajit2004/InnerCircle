package com.innercircle.util;

import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.web.reactive.function.client.WebClientResponseException;

import java.time.Duration;
import java.util.List;
import java.util.Random;
import java.util.function.Predicate;

/**
 * Retry utilities with exponential backoff and jitter for resilient external API calls.
 */
@Slf4j
public final class RetryUtil {

    private RetryUtil() {}

    /**
     * Configuration for retry behavior.
     */
    public static class RetryConfig {
        public final int maxAttempts;
        public final Duration initialDelay;
        public final Duration maxDelay;
        public final double backoffMultiplier;
        public final double jitterFactor;
        public final List<Integer> retryableStatusCodes;
        public final Predicate<Throwable> retryablePredicate;

        public RetryConfig(int maxAttempts,
                          Duration initialDelay,
                          Duration maxDelay,
                          double backoffMultiplier,
                          double jitterFactor,
                          List<Integer> retryableStatusCodes,
                          Predicate<Throwable> retryablePredicate) {
            this.maxAttempts = maxAttempts;
            this.initialDelay = initialDelay;
            this.maxDelay = maxDelay;
            this.backoffMultiplier = backoffMultiplier;
            this.jitterFactor = jitterFactor;
            this.retryableStatusCodes = retryableStatusCodes;
            this.retryablePredicate = retryablePredicate;
        }

        public static RetryConfig apiDefault() {
            return new RetryConfig(
                3,
                Duration.ofMillis(1000),
                Duration.ofSeconds(30),
                2.0,
                0.15,
                List.of(
                    HttpStatus.REQUEST_TIMEOUT.value(),
                    HttpStatus.TOO_MANY_REQUESTS.value(),
                    HttpStatus.INTERNAL_SERVER_ERROR.value(),
                    HttpStatus.BAD_GATEWAY.value(),
                    HttpStatus.SERVICE_UNAVAILABLE.value(),
                    HttpStatus.GATEWAY_TIMEOUT.value()
                ),
                t -> isRetryableByDefault(t)
            );
        }

        public static RetryConfig userRetry() {
            return new RetryConfig(
                2,
                Duration.ofMillis(500),
                Duration.ofSeconds(5),
                2.0,
                0.1,
                List.of(
                    HttpStatus.REQUEST_TIMEOUT.value(),
                    HttpStatus.TOO_MANY_REQUESTS.value(),
                    HttpStatus.INTERNAL_SERVER_ERROR.value(),
                    HttpStatus.BAD_GATEWAY.value(),
                    HttpStatus.SERVICE_UNAVAILABLE.value(),
                    HttpStatus.GATEWAY_TIMEOUT.value()
                ),
                t -> isRetryableByDefault(t)
            );
        }
    }

    

    /**
     * Default retryability check for WebClient exceptions.
     */
    private static boolean isRetryableByDefault(Throwable t) {
        // WebClientResponseException with retryable status codes
        if (t instanceof WebClientResponseException ex) {
            int status = ex.getStatusCode().value();
            return status == HttpStatus.TOO_MANY_REQUESTS.value()
                || status == HttpStatus.REQUEST_TIMEOUT.value()
                || ex.getStatusCode().is5xxServerError();
        }

        // Check for common retryable error patterns
        String msg = t.getMessage();
        if (msg == null) {
            return false;
        }
        String lower = msg.toLowerCase();
        return lower.contains("timeout")
            || lower.contains("connection")
            || lower.contains("socket")
            || lower.contains("network")
            || lower.contains("dns")
            || lower.contains("rate limit")
            || lower.contains("too many requests");
    }

    /**
     * Executes a blocking operation with retry logic.
     * Use for synchronous operations (e.g., .block() calls).
     */
    public static <T> T executeWithRetry(java.util.function.Supplier<T> operation, RetryConfig config) {
        int attempt = 0;
        Duration delay = config.initialDelay;
        Throwable lastError = null;

        while (attempt < config.maxAttempts) {
            try {
                return operation.get();
            } catch (Throwable t) {
                lastError = t;
                attempt++;

                if (attempt >= config.maxAttempts || !config.retryablePredicate.test(t)) {
                    break;
                }

                // Apply jitter
                long jitter = (long) (delay.toMillis() * config.jitterFactor * (new Random().nextDouble() * 2 - 1));
                long actualDelayMs = Math.max(0, Math.min(
                    config.maxDelay.toMillis(),
                    delay.toMillis() + jitter
                ));
                Duration actualDelay = Duration.ofMillis(actualDelayMs);

                log.warn("Retry attempt {}/{} after {}: {}",
                    attempt, config.maxAttempts, actualDelay, t.getMessage());

                try {
                    Thread.sleep(actualDelayMs);
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    throw new RuntimeException("Retry interrupted", ie);
                }

                delay = Duration.ofMillis(Math.min(
                    config.maxDelay.toMillis(),
                    (long) (delay.toMillis() * config.backoffMultiplier)
                ));
            }
        }

        throw new RetryExhaustedException(config.maxAttempts, lastError);
    }

    /**
     * Exception thrown when all retry attempts are exhausted.
     */
    public static class RetryExhaustedException extends RuntimeException {
        private final int attempts;
        private final Throwable lastError;

        public RetryExhaustedException(int attempts, Throwable lastError) {
            super("Retry exhausted after " + attempts + " attempts", lastError);
            this.attempts = attempts;
            this.lastError = lastError;
        }

        public int getAttempts() {
            return attempts;
        }

        public Throwable getLastError() {
            return lastError;
        }
    }
}