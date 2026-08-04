package com.innercircle.dto;

import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;

// FEATURE (message reactions, round 12): body for
// PUT /api/chat/messages/{messageId}/reaction. `reaction` is deliberately
// nullable and unvalidated on length/content beyond a sane cap -- it's
// meant to hold a single emoji, but there's no real harm in accepting
// whatever string the frontend's fixed emoji picker sends, and null clears
// an existing reaction (used when the user taps the same emoji again to
// remove it).
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ReactionRequest {
    private String reaction;
}