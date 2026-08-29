package com.innercircle.service;

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
            throw new IllegalArgumentException("Current password is incorrect");
        }
        user.setPasswordHash(passwordEncoder.encode(newPassword));
        userRepository.save(user);
    }

    @Transactional
    public void deleteAccount(User user) {
        userRepository.delete(user);
    }
}
