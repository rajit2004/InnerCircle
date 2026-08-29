package com.innercircle.controller;

import com.innercircle.dto.SubscriptionUpdateRequest;
import com.innercircle.dto.UpdateProfileRequest;
import com.innercircle.dto.UserProfileResponse;
import com.innercircle.model.SubscriptionTier;
import com.innercircle.model.User;
import com.innercircle.service.ChatService;
import com.innercircle.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @GetMapping("/me")
    public UserProfileResponse me(@AuthenticationPrincipal User user) {
        return toResponse(user);
    }

    @PutMapping("/me")
    public UserProfileResponse updateProfile(@AuthenticationPrincipal User user,
                                             @Valid @RequestBody UpdateProfileRequest request) {
        User updated = userService.updateProfile(user, request.getDisplayName());
        return toResponse(updated);
    }

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