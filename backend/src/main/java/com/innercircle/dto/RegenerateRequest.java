package com.innercircle.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.UUID;

@Data
public class RegenerateRequest {
    @NotNull
    private UUID personaId;

    @NotNull
    private UUID conversationId;
}
