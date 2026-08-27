package com.innercircle.service;

import com.innercircle.config.RateLimiter;
import com.innercircle.dto.AuthRequest;
import com.innercircle.dto.AuthResponse;
import com.innercircle.exception.DuplicateEmailException;
import com.innercircle.exception.TooManyRequestsException;
import com.innercircle.exception.UnauthorizedException;
import com.innercircle.model.User;
import com.innercircle.repository.UserRepository;
import com.innercircle.util.JwtUtil;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Instant;
import java.time.temporal.ChronoUnit;

@Service
@RequiredArgsConstructor
@Slf4j
public class AuthService {

    private static final int RESET_TOKEN_VALID_MINUTES = 30;
    private static final int MAX_FAILED_LOGIN_ATTEMPTS = 5;
    private static final int LOCKOUT_MINUTES = 30;
    private static final SecureRandom RANDOM = new SecureRandom();

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;
    private final EmailService emailService;
    private final RateLimiter rateLimiter;

    @Transactional
    public AuthResponse register(AuthRequest request) {
        if (userRepository.findByEmail(request.getEmail()).isPresent()) {
            throw new DuplicateEmailException("An account with this email already exists");
        }

        User user = new User();
        user.setEmail(request.getEmail());
        user.setPasswordHash(passwordEncoder.encode(request.getPassword()));

        userRepository.save(user);

        log.info("SECURITY: new user registered: {}", user.getEmail());

        String token = jwtUtil.generateToken(
                user.getId(),
                user.getEmail(),
                "USER"
        );

        return new AuthResponse(token, user.getEmail(), "USER");
    }

    @Transactional
    public AuthResponse login(AuthRequest request) {
        String email = request.getEmail().toLowerCase().trim();

        // SECURITY: rate-limit login attempts per email
        if (!rateLimiter.allowLogin(email)) {
            log.warn("SECURITY: rate-limited login attempt for: {}", email);
            throw new TooManyRequestsException("Too many login attempts. Try again in 15 minutes.");
        }

        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> {
                    log.warn("SECURITY: failed login — unknown email: {}", email);
                    return new UnauthorizedException("Invalid credentials");
                });

        // SECURITY: check account lockout
        if (user.getLockedUntil() != null && user.getLockedUntil().isAfter(Instant.now())) {
            log.warn("SECURITY: locked account login attempt: {}", email);
            throw new UnauthorizedException("Account temporarily locked. Try again later.");
        }

        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            // Increment failed attempts
            int attempts = user.getFailedLoginAttempts() + 1;
            user.setFailedLoginAttempts(attempts);

            if (attempts >= MAX_FAILED_LOGIN_ATTEMPTS) {
                user.setLockedUntil(Instant.now().plus(LOCKOUT_MINUTES, ChronoUnit.MINUTES));
                log.warn("SECURITY: account locked after {} failed attempts: {}", attempts, email);
            } else {
                log.warn("SECURITY: failed login attempt {}/{} for: {}", attempts, MAX_FAILED_LOGIN_ATTEMPTS, email);
            }

            userRepository.save(user);
            throw new UnauthorizedException("Invalid credentials");
        }

        // Successful login — reset failed attempts
        user.setFailedLoginAttempts(0);
        user.setLockedUntil(null);
        userRepository.save(user);

        log.info("SECURITY: successful login: {}", email);

        String token = jwtUtil.generateToken(
                user.getId(),
                user.getEmail(),
                "USER"
        );

        return new AuthResponse(token, user.getEmail(), "USER");
    }

    /**
     * SECURITY: rate-limited and returns same response regardless of whether
     * the email exists (prevents user enumeration).
     */
    @Transactional
    public void forgotPassword(String email) {
        String normalized = email.toLowerCase().trim();

        if (!rateLimiter.allowPasswordReset(normalized)) {
            log.warn("SECURITY: rate-limited password reset for: {}", normalized);
            throw new TooManyRequestsException("Too many reset requests. Try again in 15 minutes.");
        }

        userRepository.findByEmail(normalized).ifPresent(user -> {
            String token = generateResetToken();
            user.setResetToken(token);
            user.setResetTokenExpiresAt(Instant.now().plus(RESET_TOKEN_VALID_MINUTES, ChronoUnit.MINUTES));
            userRepository.save(user);
            log.info("SECURITY: password reset requested for: {}", normalized);
            emailService.sendPasswordResetEmail(user.getEmail(), token);
        });
    }

    @Transactional
    public void resetPassword(String token, String newPassword) {
        User user = userRepository.findByResetToken(token)
                .orElseThrow(() -> new UnauthorizedException("Invalid or expired reset code"));

        if (user.getResetTokenExpiresAt() == null || user.getResetTokenExpiresAt().isBefore(Instant.now())) {
            user.setResetToken(null);
            user.setResetTokenExpiresAt(null);
            userRepository.save(user);
            log.warn("SECURITY: expired reset token used for: {}", user.getEmail());
            throw new UnauthorizedException("Invalid or expired reset code");
        }

        user.setPasswordHash(passwordEncoder.encode(newPassword));
        user.setResetToken(null);
        user.setResetTokenExpiresAt(null);
        // SECURITY: reset failed login attempts on password change
        user.setFailedLoginAttempts(0);
        user.setLockedUntil(null);
        userRepository.save(user);

        log.info("SECURITY: password reset completed for: {}", user.getEmail());
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
