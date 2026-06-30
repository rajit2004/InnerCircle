package com.innercircle.repository;

import com.innercircle.model.Persona;
import com.innercircle.model.SubscriptionTier;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface PersonaRepository extends JpaRepository<Persona, UUID> {
    List<Persona> findBySubscriptionTierIn(List<SubscriptionTier> tiers);
}