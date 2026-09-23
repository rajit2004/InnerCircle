package com.innercircle.service;

import com.innercircle.exception.BadRequestException;
import com.innercircle.model.SubscriptionTier;
import com.innercircle.model.User;
import com.innercircle.repository.UserRepository;
import com.innercircle.util.InputSanitizer;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Transactional
    public User updateSubscriptionTier(User user, SubscriptionTier tier) {
        user.setSubscriptionTier(tier);
        return userRepository.save(user);
    }

    @Transactional
    public User updateProfile(User user, String displayName, LocalDate dateOfBirth,
                              String language, String timezone) {
        if (displayName != null) {
            String sanitized = InputSanitizer.sanitizeText(displayName.trim());
            user.setDisplayName(sanitized.isEmpty() ? null : sanitized);
        }
        if (dateOfBirth != null) {
            user.setDateOfBirth(dateOfBirth);
        }
        if (language != null && !language.isBlank()) {
            user.setLanguage(language.trim());
        }
        if (timezone != null && !timezone.isBlank()) {
            user.setTimezone(timezone.trim());
        }
        return userRepository.save(user);
    }

    @Transactional
    public void changePassword(User user, String currentPassword, String newPassword) {
        if (!passwordEncoder.matches(currentPassword, user.getPasswordHash())) {
            throw new BadRequestException("Current password is incorrect");
        }
        // SECURITY: same strength policy as register/reset
        String passwordError = InputSanitizer.validatePasswordStrength(newPassword);
        if (passwordError != null) {
            throw new BadRequestException(passwordError);
        }
        user.setPasswordHash(passwordEncoder.encode(newPassword));
        // SECURITY: revoke all outstanding JWTs so a stolen token dies with the old password
        user.setTokenVersion(user.getTokenVersion() + 1);
        userRepository.save(user);
    }

    @Transactional
    public void deleteAccount(User user) {
        userRepository.delete(user);
    }
}
