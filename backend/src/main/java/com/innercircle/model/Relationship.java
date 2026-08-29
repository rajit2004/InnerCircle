package com.innercircle.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "relationships")
@Data
@NoArgsConstructor
public class Relationship {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne
    @JoinColumn(name = "persona_id", nullable = false)
    private Persona persona;

    @Column(columnDefinition = "REAL DEFAULT 0.0")
    private double affinityScore = 0.0;

    @Column(columnDefinition = "INT DEFAULT 0")
    private int interactionCount = 0;

    private Instant lastInteractionAt;

    @Column(columnDefinition = "TEXT DEFAULT 'new'")
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
