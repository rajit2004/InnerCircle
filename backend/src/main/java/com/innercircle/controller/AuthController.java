package com.innercircle.controller;

import com.innercircle.dto.AuthRequest;
import com.innercircle.dto.AuthResponse;
import com.innercircle.dto.ForgotPasswordRequest;
import com.innercircle.dto.ResetPasswordRequest;
import com.innercircle.exception.BadRequestException;
import com.innercircle.service.AuthService;
import com.innercircle.util.InputSanitizer;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @PostMapping("/register")
    public AuthResponse register(@Valid @RequestBody AuthRequest request) {
        // SECURITY: enforce password strength on registration
        String passwordError = InputSanitizer.validatePasswordStrength(request.getPassword());
        if (passwordError != null) {
            throw new BadRequestException(passwordError);
        }
        return authService.register(request);
    }

    @PostMapping("/login")
    public AuthResponse login(@Valid @RequestBody AuthRequest request) {
        return authService.login(request);
    }

    @PostMapping("/forgot-password")
    public Map<String, String> forgotPassword(@Valid @RequestBody ForgotPasswordRequest request) {
        authService.forgotPassword(request.getEmail());
        return Map.of("status", "If that email is registered, a reset code has been sent.");
    }

    @PostMapping("/reset-password")
    public Map<String, String> resetPassword(@Valid @RequestBody ResetPasswordRequest request) {
        // SECURITY: enforce password strength on reset
        String passwordError = InputSanitizer.validatePasswordStrength(request.getNewPassword());
        if (passwordError != null) {
            throw new BadRequestException(passwordError);
        }
        authService.resetPassword(request.getToken(), request.getNewPassword());
        return Map.of("status", "Password updated. You can log in with your new password now.");
    }
}