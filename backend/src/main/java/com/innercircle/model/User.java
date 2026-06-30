package com.innercircle.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

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
    private String passwordHash;

    @Enumerated(EnumType.STRING)
    private SubscriptionTier subscriptionTier = SubscriptionTier.free;

    private int messagesUsedToday = 0;

    // FIX: needed to know whether messagesUsedToday should be reset before
    // incrementing -- without this the daily free-tier cap can never reset.
    private LocalDate lastMessageDate;

    @CreationTimestamp
    private Instant createdAt;
}