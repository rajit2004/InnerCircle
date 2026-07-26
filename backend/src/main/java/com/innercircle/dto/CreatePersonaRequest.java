package com.innercircle.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

// FEATURE (custom personas, 2026-07-06): deliberately does NOT accept a raw
// systemPrompt from the client. Free-text system prompts would bypass every
// safety/quality constraint built up through Round 8 (no markdown, short
// texting-style replies, PG-13 boundary on romantic personas) and turn
// "create a persona" into a prompt-injection surface -- someone's "custom
// personality" could just be a jailbreak attempt disguised as a persona
// description. Instead, relationshipType picks a safe template
// (see PersonaService.buildSystemPrompt) and personalityDescription is
// woven into that template as flavor, not used as the prompt outright.
@Data
public class CreatePersonaRequest {
    @NotBlank
    @Size(max = 40)
    private String name;

    // One of: PARENT, SIBLING, FRIEND, PARTNER, MENTOR, OTHER
    // (validated against that exact set in PersonaService, not bound as a
    // Java enum directly -- an unrecognized value should be a clean 400
    // with a clear message, not a JSON deserialization error)
    @NotBlank
    private String relationshipType;

    @NotBlank
    @Size(max = 300)
    private String personalityDescription;

    // Optional -- a single emoji to represent this persona in lists. Kept
    // as free text but expected to be one simple, common, single-codepoint
    // emoji, same reasoning as the emoji guidance baked into the built-in
    // persona prompts in Round 8 (compound/ZWJ emoji are the ones most
    // likely to render inconsistently across Android devices/fonts).
    private String avatarEmoji;
}