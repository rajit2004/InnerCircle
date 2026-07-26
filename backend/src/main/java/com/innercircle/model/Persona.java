package com.innercircle.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

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

    @Column(columnDefinition = "TEXT")
    private String systemPrompt;

    private String greeting;

    @Enumerated(EnumType.STRING)
    private SubscriptionTier subscriptionTier = SubscriptionTier.free;

    // BUG FIX: Lombok @Data generates getters/setters using JavaBeans conventions.
    // For a boolean field named `isActive`, Lombok generates `isIsActive()` and
    // `setIsActive()` which is wrong. JPA/Hibernate also maps the column as `is_active`
    // but the getter name collision causes issues with serialization (Jackson) and Hibernate.
    // Fix: rename the field to `active` and annotate with @Column(name = "is_active")
    // so the DB column mapping stays correct while the getter becomes `isActive()`.
    @Column(name = "is_active")
    private boolean active = true;

    // FEATURE (custom personas, 2026-07-06): null = one of the original 4
    // built-in personas, visible to everyone (subject to subscriptionTier
    // gating as before). Non-null = a persona a specific user created for
    // themselves via POST /api/personas -- only that user can see, chat
    // with, or delete it. Deliberately NOT exposed directly over JSON
    // (@JsonIgnore) -- returning the full owning User object, including its
    // password hash, to any client that fetches personas would be a real
    // data leak. PersonaController maps to PersonaResponse instead, which
    // exposes only a computed `owned` boolean relative to the requesting
    // user -- see PersonaService.toResponse().
    @ManyToOne
    @JoinColumn(name = "owner_user_id")
    @com.fasterxml.jackson.annotation.JsonIgnore
    private User owner;
}