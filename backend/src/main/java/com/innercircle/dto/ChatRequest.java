package com.innercircle.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.util.UUID;

@Data
public class ChatRequest {
    @NotNull
    private UUID personaId;

    @NotBlank
    @Size(max = 5000) // SECURITY: cap LLM token cost / DoS via multi-MB messages
    private String content;

    private UUID conversationId; // optional – if null, create new
}