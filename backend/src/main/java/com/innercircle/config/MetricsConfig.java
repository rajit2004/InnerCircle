package com.innercircle.config;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import org.springframework.context.annotation.Configuration;

import java.util.concurrent.ConcurrentHashMap;
import java.util.function.Function;

@Configuration
public class MetricsConfig {

    private final MeterRegistry meterRegistry;
    private final ConcurrentHashMap<String, Counter> counters = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, Timer> timers = new ConcurrentHashMap<>();

    public MetricsConfig(MeterRegistry meterRegistry) {
        this.meterRegistry = meterRegistry;
    }

    private Counter getOrCreateCounter(String name, String description, String... tags) {
        String key = name + "|" + String.join(",", tags);
        return counters.computeIfAbsent(key, k ->
                Counter.builder(name)
                        .description(description)
                        .tags(tags)
                        .register(meterRegistry)
        );
    }

    /**
     * Increments a counter for Groq API calls by status (success, error, rate_limited, fallback).
     */
    public void recordGroqCall(String status) {
        getOrCreateCounter("groq.api.calls", "Total Groq API calls", "status", status).increment();
    }

    /**
     * Records latency of Groq API calls.
     */
    public void recordGroqLatency(java.time.Duration duration) {
        timers.computeIfAbsent("groq.api.latency",
                k -> Timer.builder("groq.api.latency")
                        .description("Groq API call latency")
                        .publishPercentileHistogram()
                        .register(meterRegistry))
            .record(duration);
    }

    /**
     * Increments a counter for chat messages by role (user, assistant).
     */
    public void recordMessage(String role) {
        getOrCreateCounter("chat.messages", "Total chat messages", "role", role).increment();
    }

    /**
     * Increments a counter for active conversations.
     */
    public void recordActiveConversation() {
        getOrCreateCounter("conversations.active", "Active conversations").increment();
    }

    /**
     * Increments a counter for subscription changes.
     */
    public void recordSubscriptionChange(String tier) {
        getOrCreateCounter("subscription.changes", "Subscription tier changes", "tier", tier).increment();
    }

    /**
     * Records Groq token usage.
     */
    public void recordGroqTokens(long promptTokens, long completionTokens, long totalTokens) {
        getOrCreateCounter("groq.tokens.prompt", "Groq prompt tokens used").increment(promptTokens);
        getOrCreateCounter("groq.tokens.completion", "Groq completion tokens used").increment(completionTokens);
        getOrCreateCounter("groq.tokens.total", "Groq total tokens used").increment(totalTokens);
    }

    /**
     * Records stream events (token, done, error).
     */
    public void recordStreamEvent(String eventType) {
        getOrCreateCounter("stream.events", "SSE stream events", "type", eventType).increment();
    }

    /**
     * Returns a function that times an operation and records the latency.
     */
    public <T> Function<java.util.function.Supplier<T>, T> timed(String timerName) {
        Timer timer = timers.computeIfAbsent(timerName,
                k -> Timer.builder(timerName)
                        .description("Operation latency: " + timerName)
                        .publishPercentileHistogram()
                        .register(meterRegistry));
        return supplier -> timer.record(() -> supplier.get());
    }
}