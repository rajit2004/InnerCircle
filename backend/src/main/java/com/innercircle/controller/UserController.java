package com.innercircle.controller;

import com.innercircle.dto.UserProfileResponse;
import com.innercircle.model.SubscriptionTier;
import com.innercircle.model.User;
import com.innercircle.service.ChatService;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

// FEATURE (self-profile screen, 2026-07-03): see UserProfileResponse for the
// reasoning. No new SecurityConfig rule needed -- /api/users/** already falls
// under the existing .anyRequest().authenticated() rule, same as everything
// else that isn't explicitly listed under /api/auth/**, /health, or /api/admin/**.
@RestController
@RequestMapping("/api/users")
public class UserController {

    @GetMapping("/me")
    public UserProfileResponse me(@AuthenticationPrincipal User user) {
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
