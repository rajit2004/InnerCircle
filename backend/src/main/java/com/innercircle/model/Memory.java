package src.main.java.com.innercircle.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.ColumnTransformer;
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

    // BUG FIX: Hibernate's columnDefinition only controls DDL (schema
    // generation) -- it does NOT change what JDBC type gets bound on INSERT.
    // The driver was sending this as a plain varchar parameter, and Postgres
    // rejected it: "column 'embedding' is of type vector but expression is
    // of type character varying". @ColumnTransformer adds an explicit
    // ::vector cast into the generated SQL on write (and a ::text cast back
    // on read, so reads still come back as a plain String), while the Java
    // field stays a normal String -- no extra pgvector Hibernate type
    // library needed.
    @Column(columnDefinition = "vector(1536)")
    @ColumnTransformer(write = "?::vector", read = "embedding::text")
    private String embedding;  // pgvector literal text, e.g. "[0.1,0.2,...]" -- see EmbeddingService

    private int importance = 1;
    private int accessCount = 0;
    private Instant lastAccessed;

    @CreationTimestamp
    private Instant createdAt;
}