package com.innercircle.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "memories")
@Data
@NoArgsConstructor
public class Memory {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne
    @JoinColumn(name = "persona_id")
    private Persona persona;  // null = shared across personas

    @Column(columnDefinition = "TEXT", nullable = false)
    private String fact;

    @Column(columnDefinition = "vector(1536)")
    private String embedding;  // placeholder – we'll implement pgvector later

    private int importance = 1;
    private int accessCount = 0;
    private Instant lastAccessed;

    @CreationTimestamp
    private Instant createdAt;
}