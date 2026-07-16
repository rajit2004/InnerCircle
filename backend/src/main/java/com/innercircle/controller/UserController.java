package com.innercircle.controller;

import com.innercircle.dto.SubscriptionUpdateRequest;
import com.innercircle.dto.UserProfileResponse;
import com.innercircle.model.SubscriptionTier;
import com.innercircle.model.User;
import com.innercircle.service.ChatService;
import com.innercircle.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

// FEATURE (self-profile screen, 2026-07-03): see UserProfileResponse for the
// reasoning. No new SecurityConfig rule needed -- /api/users/** already falls
// under the existing .anyRequest().authenticated() rule, same as everything
// else that isn't explicitly listed under /api/auth/**, /health, or /api/admin/**.
@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @GetMapping("/me")
    public UserProfileResponse me(@AuthenticationPrincipal User user) {
        return toResponse(user);
    }

    // FEATURE (subscription upgrade, 2026-07-04): mock/manual tier toggle --
    // see UserService for why this is deliberately not dressed up as a real
    // payment flow. Returns the updated profile so the frontend can refresh
    // its display in one round trip instead of needing a second GET /me.
    @PostMapping("/subscription")
    public UserProfileResponse updateSubscription(@AuthenticationPrincipal User user,
                                                  @Valid @RequestBody SubscriptionUpdateRequest request) {
        User updated = userService.updateSubscriptionTier(user, request.getTier());
        return toResponse(updated);
    }

    private UserProfileResponse toResponse(User user) {
        boolean isPremium = user.getSubscriptionTier() == SubscriptionTier.premium;

        return new UserProfileResponse(
                user.getId(),
                user.getEmail(),
                user.getDisplayName(),
                user.getSubscriptionTier().name(),
                user.getMessagesUsedToday(),
                isPremium ? 0 : ChatService.FREE_TIER_DAILY_MESSAGE_LIMIT,
                user.getLastMessageDate(),
                user.getCreatedAt()
        );
    }
}