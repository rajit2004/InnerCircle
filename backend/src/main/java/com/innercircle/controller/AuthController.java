package com.innercircle.controller;

import com.innercircle.dto.AuthRequest;
import com.innercircle.dto.AuthResponse;
import com.innercircle.dto.ForgotPasswordRequest;
import com.innercircle.dto.ResetPasswordRequest;
import com.innercircle.service.AuthService;
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
        return authService.register(request);
    }

    @PostMapping("/login")
    public AuthResponse login(@Valid @RequestBody AuthRequest request) {
        return authService.login(request);
    }

    // FEATURE (forgot password, 2026-07-06): both endpoints fall under the
    // existing /api/auth/** permitAll rule in SecurityConfig already, so no
    // security config changes were needed. Both return the same
    // success-shaped response regardless of whether the email actually
    // matches an account -- see AuthService.forgotPassword() for why that's
    // deliberate, not an oversight.
    @PostMapping("/forgot-password")
    public Map<String, String> forgotPassword(@Valid @RequestBody ForgotPasswordRequest request) {
        authService.forgotPassword(request.getEmail());
        return Map.of("status", "If that email is registered, a reset code has been sent.");
    }

    @PostMapping("/reset-password")
    public Map<String, String> resetPassword(@Valid @RequestBody ResetPasswordRequest request) {
        authService.resetPassword(request.getToken(), request.getNewPassword());
        return Map.of("status", "Password updated. You can log in with your new password now.");
    }
}