package com.innercircle.service;

import com.innercircle.model.SubscriptionTier;
import com.innercircle.model.User;
import com.innercircle.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

// FEATURE (subscription upgrade, 2026-07-04): previously there was no way
// for a user to change their own subscriptionTier at all -- it was whatever
// the DB seeded (or, for accounts created through normal registration,
// always SubscriptionTier.free forever). Premium personas existed and were
// correctly gated by PersonaService/ChatService, but there was no path to
// actually reach that gate from the "free" side. This is a direct,
// mock/manual toggle -- there's no payment gateway integrated in this
// project, so it's built to be exactly what it is rather than dressed up
// to look like a real checkout flow.
@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;

    @Transactional
    public User updateSubscriptionTier(User user, SubscriptionTier tier) {
        user.setSubscriptionTier(tier);
        return userRepository.save(user);
    }
}