package com.innercircle.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
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
    private LocalDate lastMessageDate;

    private LocalDate dateOfBirth;
    private String language = "en";
    private String timezone = "UTC";

    @JsonIgnore
    private String resetToken;
    @JsonIgnore
    private Instant resetTokenExpiresAt;

    @JsonIgnore
    private int failedLoginAttempts = 0;
    @JsonIgnore
    private Instant lockedUntil;

    @CreationTimestamp
    private Instant createdAt;

    @UpdateTimestamp
    private Instant updatedAt;

    @Version
    private Long version;
}
