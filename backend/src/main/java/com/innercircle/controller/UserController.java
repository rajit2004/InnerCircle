package com.innercircle.controller;

import com.innercircle.dto.ChangePasswordRequest;
import com.innercircle.dto.SubscriptionUpdateRequest;
import com.innercircle.dto.UpdateProfileRequest;
import com.innercircle.dto.UserProfileResponse;
import com.innercircle.model.SubscriptionTier;
import com.innercircle.model.User;
import com.innercircle.service.ChatService;
import com.innercircle.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.UUID;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    private static final String AVATAR_DIR = "uploads/avatars/";
    private static final long MAX_AVATAR_SIZE = 5 * 1024 * 1024; // 5MB

    @GetMapping("/me")
    public UserProfileResponse me(@AuthenticationPrincipal User user) {
        return toResponse(user);
    }

    @PutMapping("/me")
    public UserProfileResponse updateProfile(@AuthenticationPrincipal User user,
                                             @Valid @RequestBody UpdateProfileRequest request) {
        User updated = userService.updateProfile(
                user,
                request.getDisplayName(),
                request.getDateOfBirth(),
                request.getLanguage(),
                request.getTimezone()
        );
        return toResponse(updated);
    }

    @PostMapping(value = "/me/avatar", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public UserProfileResponse uploadAvatar(@AuthenticationPrincipal User user,
                                            @RequestParam("file") MultipartFile file) throws IOException {
        if (file.isEmpty()) {
            throw new IllegalArgumentException("File is empty");
        }
        if (file.getSize() > MAX_AVATAR_SIZE) {
            throw new IllegalArgumentException("File must be under 5MB");
        }

        String originalName = file.getOriginalFilename();
        if (originalName == null) originalName = "avatar.jpg";
        String ext = originalName.contains(".")
                ? originalName.substring(originalName.lastIndexOf('.') + 1)
                : "jpg";

        String filename = user.getId() + "." + ext;
        Path dir = Paths.get(AVATAR_DIR);
        Files.createDirectories(dir);
        Files.copy(file.getInputStream(), dir.resolve(filename), java.nio.file.StandardCopyOption.REPLACE_EXISTING);

        String avatarUrl = "/uploads/avatars/" + filename;
        user.setAvatarUrl(avatarUrl);
        User updated = userService.updateProfile(user, null, null, null, null);
        return toResponse(updated);
    }

    @PutMapping("/me/password")
    public ResponseEntity<Void> changePassword(@AuthenticationPrincipal User user,
                                               @Valid @RequestBody ChangePasswordRequest request) {
        userService.changePassword(user, request.getCurrentPassword(), request.getNewPassword());
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/me")
    public ResponseEntity<Void> deleteAccount(@AuthenticationPrincipal User user) {
        userService.deleteAccount(user);
        return ResponseEntity.noContent().build();
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
                user.getAvatarUrl(),
                user.getSubscriptionTier().name(),
                user.getMessagesUsedToday(),
                isPremium ? 0 : ChatService.FREE_TIER_DAILY_MESSAGE_LIMIT,
                user.getLastMessageDate(),
                user.getDateOfBirth(),
                user.getLanguage(),
                user.getTimezone(),
                user.getCreatedAt()
        );
    }
}
