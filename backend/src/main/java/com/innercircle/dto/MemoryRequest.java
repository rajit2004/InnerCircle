package com.innercircle.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

import java.util.UUID;

@Data
public class MemoryRequest {
    @NotBlank
    private String fact;

    private UUID personaId;

    // FEATURE (shared memory, 2026-07-02): Lets a manually-created memory
    // (via POST /api/memories) opt into being visible across all personas,
    // same as facts the LLM extraction marks shared = true. Defaults to
    // false -- manually added facts stay scoped to the given persona unless
    // explicitly marked otherwise.
    private boolean shared = false;
}