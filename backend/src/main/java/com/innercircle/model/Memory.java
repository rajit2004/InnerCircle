package com.innercircle.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.ColumnTransformer;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

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
    private Persona persona;

    @Column(columnDefinition = "TEXT", nullable = false)
    private String fact;

    @Column(columnDefinition = "TEXT")
    private String content;

    private String memoryType = "fact";

    @Column(columnDefinition = "vector(1536)")
    @ColumnTransformer(write = "?::vector", read = "embedding::text")
    private String embedding;

    private int importance = 1;
    private int accessCount = 0;
    private Instant lastAccessed;
    private boolean shared = false;
    private Instant deletedAt;

    @CreationTimestamp
    private Instant createdAt;

    @UpdateTimestamp
    private Instant updatedAt;
}
