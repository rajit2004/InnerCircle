package com.innercircle.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import com.innercircle.model.SubscriptionTier;

// FEATURE (subscription upgrade, 2026-07-04): backs POST /api/users/subscription.
// There's no real payment gateway wired into this project (no Stripe/Play
// Billing integration), so this is intentionally a direct, honest toggle --
// not dressed up to look like a real checkout flow. See UserService and
// ProfileScreen for the matching frontend piece.
@Data
public class SubscriptionUpdateRequest {
    @NotNull
    private SubscriptionTier tier;
}