package com.innercircle.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.Instant;

@Entity
@Table(name = "relationships")
@Data
@NoArgsConstructor
public class Relationship {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private java.util.UUID id;

    @ManyToOne
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne
    @JoinColumn(name = "persona_id", nullable = false)
    private Persona persona;

    private double affinityScore = 0.0;
    private int interactionCount = 0;
    private Instant lastInteractionAt;

    private String relationshipStage = "new";

    @Column(columnDefinition = "TEXT DEFAULT '[]'")
    private String insideJokes = "[]";

    @Column(columnDefinition = "TEXT DEFAULT '[]'")
    private String sharedTopics = "[]";

    private String preferredResponseStyle;
    private String userNickname;

    @CreationTimestamp
    private Instant createdAt;

    @UpdateTimestamp
    private Instant updatedAt;
}
