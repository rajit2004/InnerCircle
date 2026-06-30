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

    /**
     * Vector similarity search using pgvector's cosine distance operator (<=>).
     * Matches memories tied to the given persona OR not tied to any persona
     * (shared/global facts). Falls back to nothing if no memory has an
     * embedding yet -- callers should have a non-vector fallback for that case.
     */
    @Query(value = """
            SELECT * FROM memories
            WHERE user_id = :userId
              AND (persona_id = :personaId OR persona_id IS NULL)
              AND embedding IS NOT NULL
            ORDER BY embedding <=> CAST(:queryEmbedding AS vector)
            LIMIT :limit
            """, nativeQuery = true)
    List<Memory> findRelevantMemories(@Param("userId") UUID userId,
                                      @Param("personaId") UUID personaId,
                                      @Param("queryEmbedding") String queryEmbedding,
                                      @Param("limit") int limit);
}
