package com.innercircle.repository;

import com.innercircle.model.Memory;
import com.innercircle.model.Persona;
import com.innercircle.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.UUID;

public interface MemoryRepository extends JpaRepository<Memory, UUID> {

    List<Memory> findByUserAndPersonaOrderByImportanceDesc(User user, Persona persona);

    List<Memory> findByUserOrderByImportanceDesc(User user);

    // FEATURE (shared memory, 2026-07-02): New method used everywhere a
    // persona-scoped memory list is needed but should ALSO include memories
    // explicitly marked shared = true from other personas. Kept as a
    // separate method (rather than modifying findByUserAndPersonaOrderByImportanceDesc)
    // so existing strictly-persona-scoped call sites, if any get added later,
    // aren't silently changed.
    @Query("""
            SELECT m FROM Memory m
            WHERE m.user = :user
              AND (m.persona = :persona OR m.shared = true)
            ORDER BY m.importance DESC
            """)
    List<Memory> findByUserAndPersonaOrSharedOrderByImportanceDesc(@Param("user") User user,
                                                                   @Param("persona") Persona persona);

    /**
     * Vector similarity search using pgvector's cosine distance operator (<=>).
     * Matches memories tied to the given persona, OR not tied to any persona
     * (persona_id IS NULL), OR explicitly marked shared = true regardless of
     * which persona they were extracted under. Falls back to nothing if no
     * memory has an embedding yet -- callers should have a non-vector fallback
     * for that case (see MemoryService.findRelevantMemories).
     */
    @Query(value = """
            SELECT * FROM memories
            WHERE user_id = :userId
              AND (persona_id = :personaId OR persona_id IS NULL OR shared = TRUE)
              AND embedding IS NOT NULL
            ORDER BY embedding <=> CAST(:queryEmbedding AS vector)
            LIMIT :limit
            """, nativeQuery = true)
    List<Memory> findRelevantMemories(@Param("userId") UUID userId,
                                      @Param("personaId") UUID personaId,
                                      @Param("queryEmbedding") String queryEmbedding,
                                      @Param("limit") int limit);
}