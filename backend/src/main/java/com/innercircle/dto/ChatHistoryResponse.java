package com.innercircle.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

// FEATURE (chat history, 2026-07-02): response shape for GET /api/chat/history.
// conversationId is null when the user has never chatted with this persona
// before -- the frontend should fall back to just showing the persona's
// greeting in that case, same as it already does today.
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ChatHistoryResponse {
    private UUID conversationId;
    private List<MessageDto> messages;

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class MessageDto {
        private String role;
        private String content;
        private Instant createdAt;
    }
}