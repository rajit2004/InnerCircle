package com.innercircle.service;

import com.innercircle.model.SubscriptionTier;
import com.innercircle.model.User;
import com.innercircle.repository.UserRepository;
import com.innercircle.util.InputSanitizer;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;

    @Transactional
    public User updateSubscriptionTier(User user, SubscriptionTier tier) {
        user.setSubscriptionTier(tier);
        return userRepository.save(user);
    }

    @Transactional
    public User updateProfile(User user, String displayName) {
        if (displayName != null) {
            String sanitized = InputSanitizer.sanitizeText(displayName.trim());
            if (sanitized.isEmpty()) {
                user.setDisplayName(null);
            } else {
                user.setDisplayName(sanitized);
            }
        }
        return userRepository.save(user);
    }
}