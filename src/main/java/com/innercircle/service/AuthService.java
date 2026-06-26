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

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;

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

        // ✅ Pass 3 arguments: token, email, role
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

        // ✅ Pass 3 arguments
        return new AuthResponse(token, user.getEmail(), "USER");
    }
}