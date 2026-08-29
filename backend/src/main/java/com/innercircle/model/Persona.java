package com.innercircle.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "personas")
@Data
@NoArgsConstructor
public class Persona {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    private String name;
    private String role;
    private String avatarEmoji;
    private String personality;
    private String voice;

    @Column(columnDefinition = "TEXT")
    private String systemPrompt;

    private String greeting;

    @Column(name = "nsfw_enabled")
    private boolean nsfwEnabled = false;

    @Enumerated(EnumType.STRING)
    private SubscriptionTier subscriptionTier = SubscriptionTier.free;

    @Column(name = "is_active")
    private boolean active = true;

    @ManyToOne
    @JoinColumn(name = "owner_user_id")
    @com.fasterxml.jackson.annotation.JsonIgnore
    private User owner;

    @ManyToOne
    @JoinColumn(name = "user_id")
    @com.fasterxml.jackson.annotation.JsonIgnore
    private User user;

    @CreationTimestamp
    private Instant createdAt;
}
