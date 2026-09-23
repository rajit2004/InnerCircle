package com.innercircle.dto;

import jakarta.validation.constraints.Size;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;

// FEATURE (message reactions, round 12): body for
// PUT /api/chat/messages/{messageId}/reaction. `reaction` is deliberately
// nullable (clears an existing reaction when the user taps the same emoji
// again) and capped at 16 chars — enough for any single emoji including
// ZWJ sequences, without allowing arbitrary-length strings into the DB.
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ReactionRequest {
    @Size(max = 16)
    private String reaction;
}