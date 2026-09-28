package com.innercircle.service;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for the Groq SSE payload parsing used by chat streaming.
 */
class ChatStreamDeltaTest {

    @Test
    void extractDelta_returnsTextContent() {
        String payload = """
                {"id":"x","choices":[{"index":0,"delta":{"content":"Hello"},"finish_reason":null}]}""";
        assertEquals("Hello", ChatService.extractDelta(payload));
    }

    @Test
    void extractDelta_returnsEmptyForRoleOnlyChunk() {
        String payload = """
                {"id":"x","choices":[{"index":0,"delta":{"role":"assistant"},"finish_reason":null}]}""";
        String delta = ChatService.extractDelta(payload);
        assertTrue(delta == null || delta.isEmpty());
    }

    @Test
    void extractDelta_returnsEmptyForFinishReasonChunk() {
        String payload = """
                {"id":"x","choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}""";
        String delta = ChatService.extractDelta(payload);
        assertTrue(delta == null || delta.isEmpty());
    }

    @Test
    void extractDelta_returnsNullForMalformedJson() {
        assertNull(ChatService.extractDelta("{not json"));
    }

    @Test
    void extractDelta_returnsNullForEmptyChoices() {
        assertNull(ChatService.extractDelta("{\"choices\":[]}"));
    }

    @Test
    void extractDelta_handlesUnicodeContent() {
        String payload = """
                {"choices":[{"delta":{"content":"café ❤️\\nnew line"}}]}""";
        assertEquals("café ❤️\nnew line", ChatService.extractDelta(payload));
    }
}
