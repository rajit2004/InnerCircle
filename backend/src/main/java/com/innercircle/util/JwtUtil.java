package com.innercircle.util;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.UUID;

@Component
public class JwtUtil {

    private static final String DEFAULT_SECRET = "your-super-secret-jwt-key-change-in-production";

    @Value("${jwt.secret}")
    private String secret;

    @Value("${jwt.expiration}")
    private long expiration;

    @Value("${jwt.require-secret:false}")
    private boolean requireSecret;

    // SECURITY: fail fast (or loudly warn) if the well-known default secret is
    // still in use -- anyone could forge a valid (even admin) JWT. Set
    // JWT_SECRET in the environment for any real deployment. Set
    // JWT_REQUIRE_SECRET=true to hard-fail startup instead of just warning.
    @jakarta.annotation.PostConstruct
    public void validateSecret() {
        if (secret == null || secret.equals(DEFAULT_SECRET)) {
            if (requireSecret) {
                throw new IllegalStateException(
                        "JWT_SECRET is not set (or is still the default placeholder). " +
                                "Set the JWT_SECRET environment variable before starting in production.");
            }
            org.slf4j.LoggerFactory.getLogger(JwtUtil.class).error(
                    "SECURITY WARNING: JWT secret is the default placeholder. Anyone can forge tokens. " +
                            "Set JWT_SECRET in the environment for any real deployment.");
        }
    }

    private SecretKey getSigningKey() {
        return Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
    }

    public String generateToken(UUID userId, String email, String role) {
        return Jwts.builder()
                .subject(userId.toString())
                .claim("email", email)
                .claim("role", role != null ? role : "USER")
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + expiration))
                .signWith(getSigningKey())
                .compact();
    }

    public Claims extractAllClaims(String token) {
        return Jwts.parser()
                .verifyWith(getSigningKey())
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    public String extractUserId(String token) {
        return extractAllClaims(token).getSubject();
    }

    public String extractEmail(String token) {
        return extractAllClaims(token).get("email", String.class);
    }

    public String extractRole(String token) {
        return extractAllClaims(token).get("role", String.class);
    }

    public boolean validateToken(String token) {
        try {
            extractAllClaims(token);
            return true;
        } catch (Exception e) {
            return false;
        }
    }
}