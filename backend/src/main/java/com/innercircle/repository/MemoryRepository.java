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

    @Query("""
            SELECT m FROM Memory m
            WHERE m.user = :user AND m.persona = :persona AND m.deletedAt IS NULL
            ORDER BY m.importance DESC
            """)
    List<Memory> findActiveByUserAndPersona(@Param("user") User user, @Param("persona") Persona persona);

    @Query("""
            SELECT m FROM Memory m
            WHERE m.user = :user AND m.deletedAt IS NULL
            ORDER BY m.importance DESC
            """)
    List<Memory> findActiveByUser(@Param("user") User user);

    @Query("""
            SELECT m FROM Memory m
            WHERE m.user = :user
              AND (m.persona = :persona OR m.shared = true)
              AND m.deletedAt IS NULL
            ORDER BY m.importance DESC
            """)
    List<Memory> findActiveByUserAndPersonaOrShared(@Param("user") User user,
                                                    @Param("persona") Persona persona);

    @Query(value = """
            SELECT * FROM memories
            WHERE user_id = :userId
              AND (persona_id = :personaId OR persona_id IS NULL OR shared = TRUE)
              AND embedding IS NOT NULL
              AND deleted_at IS NULL
            ORDER BY embedding <=> CAST(:queryEmbedding AS vector)
            LIMIT :limit
            """, nativeQuery = true)
    List<Memory> findRelevantMemories(@Param("userId") UUID userId,
                                      @Param("personaId") UUID personaId,
                                      @Param("queryEmbedding") String queryEmbedding,
                                      @Param("limit") int limit);
}
