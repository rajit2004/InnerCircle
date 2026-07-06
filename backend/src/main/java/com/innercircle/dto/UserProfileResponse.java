package com.innercircle.dto;

import lombok.AllArgsConstructor;
import lombok.Data;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

// FEATURE (self-profile screen, 2026-07-03): previously there was no endpoint
// for a client to ask "who am I / what's my real account status" -- the
// frontend was inferring subscriptionTier by checking whether any persona in
// GET /api/personas happened to be premium-tier, which only worked because
// PersonaService already filters premium personas out for free users. That's
// an indirect, easy-to-break way to answer a question the backend can just
// answer directly. This DTO backs a real GET /api/users/me.
@Data
@AllArgsConstructor
public class UserProfileResponse {
    private UUID id;
    private String email;
    private String displayName;
    private String subscriptionTier;
    private int messagesUsedToday;
    private int dailyMessageLimit;   // 0 = unlimited (premium)
    private LocalDate lastMessageDate;
    private Instant memberSince;
}
