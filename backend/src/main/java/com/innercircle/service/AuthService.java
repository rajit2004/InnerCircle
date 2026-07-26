package com.innercircle.service;

import com.innercircle.dto.AuthRequest;
import com.innercircle.dto.AuthResponse;
import com.innercircle.exception.DuplicateEmailException;
import com.innercircle.exception.UnauthorizedException;
import com.innercircle.model.User;
import com.innercircle.repository.UserRepository;
import com.innercircle.util.JwtUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Instant;
import java.time.temporal.ChronoUnit;

@Service
@RequiredArgsConstructor
public class AuthService {

    private static final int RESET_TOKEN_VALID_MINUTES = 30;
    private static final SecureRandom RANDOM = new SecureRandom();

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;
    private final EmailService emailService;

    @Transactional
    public AuthResponse register(AuthRequest request) {
        if (userRepository.findByEmail(request.getEmail()).isPresent()) {
            throw new DuplicateEmailException("An account with this email already exists");
        }

        User user = new User();
        user.setEmail(request.getEmail());
        user.setPasswordHash(passwordEncoder.encode(request.getPassword()));

        userRepository.save(user);

        String token = jwtUtil.generateToken(
                user.getId(),
                user.getEmail(),
                "USER"
        );

        return new AuthResponse(token, user.getEmail(), "USER");
    }

    @Transactional
    public AuthResponse login(AuthRequest request) {
        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new UnauthorizedException("Invalid credentials"));

        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            throw new UnauthorizedException("Invalid credentials");
        }

        String token = jwtUtil.generateToken(
                user.getId(),
                user.getEmail(),
                "USER"
        );

        return new AuthResponse(token, user.getEmail(), "USER");
    }

    /**
     * FEATURE (forgot password, 2026-07-06): deliberately does NOT throw or
     * respond any differently whether or not the email exists -- revealing
     * "this email isn't registered" from an unauthenticated endpoint is a
     * classic account-enumeration leak (lets someone silently check which
     * emails have accounts here at all). The caller always gets back the
     * same success-shaped response; if the email happens to match a real
     * account, that account gets a fresh token and an email attempt behind
     * the scenes. If not, nothing happens and nobody outside this method
     * can tell the difference.
     */
    @Transactional
    public void forgotPassword(String email) {
        userRepository.findByEmail(email).ifPresent(user -> {
            String token = generateResetToken();
            user.setResetToken(token);
            user.setResetTokenExpiresAt(Instant.now().plus(RESET_TOKEN_VALID_MINUTES, ChronoUnit.MINUTES));
            userRepository.save(user);
            emailService.sendPasswordResetEmail(user.getEmail(), token);
        });
    }

    @Transactional
    public void resetPassword(String token, String newPassword) {
        User user = userRepository.findByResetToken(token)
                .orElseThrow(() -> new UnauthorizedException("Invalid or expired reset code"));

        if (user.getResetTokenExpiresAt() == null || user.getResetTokenExpiresAt().isBefore(Instant.now())) {
            // Clear it either way -- an expired token shouldn't stay usable
            // forever just because nobody happened to try it again.
            user.setResetToken(null);
            user.setResetTokenExpiresAt(null);
            userRepository.save(user);
            throw new UnauthorizedException("Invalid or expired reset code");
        }

        user.setPasswordHash(passwordEncoder.encode(newPassword));
        user.setResetToken(null);
        user.setResetTokenExpiresAt(null);
        userRepository.save(user);
    }

    private String generateResetToken() {
        byte[] bytes = new byte[24];
        RANDOM.nextBytes(bytes);
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }
}