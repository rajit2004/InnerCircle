package com.innercircle.repository;

import com.innercircle.model.Persona;
import com.innercircle.model.SubscriptionTier;
import com.innercircle.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.UUID;

public interface PersonaRepository extends JpaRepository<Persona, UUID> {

    // FEATURE (custom personas, 2026-07-06): replaces the old
    // findBySubscriptionTierIn(tiers) -- that method only ever handled tier
    // gating for the built-in personas and had no concept of ownership at
    // all, so it couldn't distinguish "everyone's custom personas" from
    // "just mine." This combines both conditions: built-in personas
    // (owner IS NULL) still gated by subscription tier exactly as before,
    // PLUS every custom persona the requesting user owns, regardless of
    // its tier -- while still correctly excluding every OTHER user's
    // custom personas.
    //
    // Also fixes a latent gap in the method it replaces: that query never
    // filtered on `active` at all, meaning a deactivated persona would still
    // show up for everyone. Adding `p.active = true` here closes that.
    @Query("""
            SELECT p FROM Persona p
            WHERE p.active = true
              AND (
                (p.owner IS NULL AND p.subscriptionTier IN :tiers)
                OR p.owner = :user
              )
            ORDER BY p.name
            """)
    List<Persona> findVisibleTo(@Param("user") User user, @Param("tiers") List<SubscriptionTier> tiers);
}