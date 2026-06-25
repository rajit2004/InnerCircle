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
}
