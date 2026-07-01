package com.innercircle.model;

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
    private Persona persona;  // null = created outside any specific persona context

    @Column(columnDefinition = "TEXT", nullable = false)
    private String fact;

    @Column(columnDefinition = "vector(1536)")
    @ColumnTransformer(write = "?::vector", read = "embedding::text")
    private String embedding;  // pgvector literal text, e.g. "[0.1,0.2,...]" -- see EmbeddingService

    private int importance = 1;
    private int accessCount = 0;
    private Instant lastAccessed;

    // FEATURE (shared memory, 2026-07-02): Previously the only way for a memory
    // to be visible across all personas was persona = null, which meant "not
    // tied to any persona" -- but nothing in the app ever actually created a
    // memory that way, so every fact was silently siloed to whichever persona
    // the user happened to be chatting with when it was extracted. This meant
    // "tell Mom I want a hamburger" said to Big Sister never reached Mom --
    // Big Sister would generate a reply that sounded like she'd relay it, but
    // structurally there was no mechanism to do so.
    //
    // `shared` is the explicit, intentional version of that: a memory with
    // shared = true is returned to every persona's context regardless of
    // which persona it was originally extracted under (see
    // MemoryRepository's queries below). It's set by MemoryService when the
    // user's message contains relay/share intent -- see
    // MemoryService.extractAndStoreMemory() for the detection logic.
    private boolean shared = false;

    @CreationTimestamp
    private Instant createdAt;
}