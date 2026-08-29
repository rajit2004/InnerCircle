package com.innercircle.repository;

import com.innercircle.model.Relationship;
import com.innercircle.model.User;
import com.innercircle.model.Persona;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface RelationshipRepository extends JpaRepository<Relationship, UUID> {
    Optional<Relationship> findByUserIdAndPersonaId(UUID userId, UUID personaId);
    Optional<Relationship> findByUserAndPersona(User user, Persona persona);
}
