package com.innercircle.repository;

import com.innercircle.model.Persona;
import com.innercircle.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.UUID;

public interface PersonaRepository extends JpaRepository<Persona, UUID> {

    // All active built-in personas (owner IS NULL) plus the requesting
    // user's own custom personas.  Tier filtering for display is handled
    // on the client -- the backend still enforces access at chat time
    // via PersonaService.isPersonaAccessible().
    @Query("""
            SELECT p FROM Persona p
            WHERE p.active = true
              AND (
                p.owner IS NULL
                OR p.owner = :user
              )
            ORDER BY p.name
            """)
    List<Persona> findVisibleTo(@Param("user") User user);
}