package com.innercircle.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import com.fasterxml.jackson.annotation.JsonIgnore;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "profiles")
@Data
@NoArgsConstructor
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false, unique = true)
    private String email;

    private String displayName;
    private String avatarUrl;

    @Column(nullable = false)
    @JsonIgnore
    private String passwordHash;

    @Enumerated(EnumType.STRING)
    private SubscriptionTier subscriptionTier = SubscriptionTier.free;

    private int messagesUsedToday = 0;

    // FIX: needed to know whether messagesUsedToday should be reset before
    // incrementing -- without this the daily free-tier cap can never reset.
    private LocalDate lastMessageDate;

    // FEATURE (forgot password, 2026-07-06): a pending reset token + its
    // expiry, both cleared once the reset completes or expires. See
    // AuthService.forgotPassword() / resetPassword() for the actual flow.
    @JsonIgnore
    private String resetToken;
    @JsonIgnore
    private Instant resetTokenExpiresAt;

    // SECURITY: account lockout after too many failed login attempts.
    // failedAttempts resets on successful login; lockedUntil is set to a
    // future timestamp when the account should auto-unlock.
    @JsonIgnore
    private int failedLoginAttempts = 0;
    @JsonIgnore
    private Instant lockedUntil;

    @CreationTimestamp
    private Instant createdAt;

    // OPTIMISTIC LOCK: prevents two concurrent chat requests from both
    // reading+incrementing messagesUsedToday and losing an update (soft-cap
    // race). Hibernate checks this on save() and throws if the row changed
    // underneath us.
    @Version
    private Long version;
}