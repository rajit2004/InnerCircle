package com.innercircle.repository;

import com.innercircle.model.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface UserRepository extends JpaRepository<User, UUID> {
    Optional<User> findByEmail(String email);
    boolean existsByEmail(String email);

    // FEATURE (forgot password, 2026-07-06): looks up whichever user currently
    // holds this reset token. See AuthService.resetPassword().
    Optional<User> findByResetToken(String token);
}