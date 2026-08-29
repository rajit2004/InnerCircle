package com.innercircle.service;

import com.innercircle.model.Persona;
import com.innercircle.model.Relationship;
import com.innercircle.model.User;
import com.innercircle.repository.RelationshipRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

/**
 * Layer 2 of the 5-layer behavioral architecture.
 * Tracks the relationship between a user and a persona over time.
 * Provides context about interaction history, affinity, inside jokes,
 * and relationship stage.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class RelationshipService {

    private final RelationshipRepository relationshipRepository;

    /**
     * Get or create the relationship between a user and persona.
     */
    @Transactional
    public Relationship getOrCreateRelationship(User user, Persona persona) {
        return relationshipRepository.findByUserAndPersona(user, persona)
                .orElseGet(() -> {
                    Relationship rel = new Relationship();
                    rel.setUser(user);
                    rel.setPersona(persona);
                    rel.setAffinityScore(0.0);
                    rel.setInteractionCount(0);
                    rel.setRelationshipStage("new");
                    rel.setInsideJokes("[]");
                    rel.setSharedTopics("[]");
                    return relationshipRepository.save(rel);
                });
    }

    /**
     * Update relationship after a conversation turn.
     * Increases affinity, updates interaction count, tracks shared topics.
     */
    @Transactional
    public void recordInteraction(User user, Persona persona, String topic, String emotion) {
        Relationship rel = getOrCreateRelationship(user, persona);

        rel.setInteractionCount(rel.getInteractionCount() + 1);
        rel.setLastInteractionAt(Instant.now());

        // Affinity increases with each interaction, with diminishing returns
        double currentAffinity = rel.getAffinityScore();
        double increment = Math.max(0.1, 1.0 - (currentAffinity / 100.0));
        rel.setAffinityScore(Math.min(100.0, currentAffinity + increment));

        // Update relationship stage based on interaction count and affinity
        if (rel.getInteractionCount() > 50 && currentAffinity > 60) {
            rel.setRelationshipStage("deep");
        } else if (rel.getInteractionCount() > 20 && currentAffinity > 30) {
            rel.setRelationshipStage("established");
        } else if (rel.getInteractionCount() > 5) {
            rel.setRelationshipStage("building");
        }

        // Track shared topics (keep last 20 unique topics)
        if (topic != null && !topic.isBlank()) {
            try {
                List<String> topics = new java.util.ArrayList<>(
                        (List<String>) com.fasterxml.jackson.databind.ObjectMapper.class
                                .getDeclaredConstructor()
                                .newInstance()
                                .readValue(rel.getSharedTopics(), List.class)
                );
                if (!topics.contains(topic)) {
                    topics.add(topic);
                    if (topics.size() > 20) {
                        topics = topics.subList(topics.size() - 20, topics.size());
                    }
                    rel.setSharedTopics(new com.fasterxml.jackson.databind.ObjectMapper()
                            .writeValueAsString(topics));
                }
            } catch (Exception e) {
                log.debug("Failed to update shared topics: {}", e.getMessage());
            }
        }

        relationshipRepository.save(rel);
    }

    /**
     * Get relationship context for prompt building.
     * Returns a human-readable string describing the relationship state.
     */
    public String getRelationshipContext(Relationship rel) {
        if (rel == null) return "";

        StringBuilder ctx = new StringBuilder();
        ctx.append("RELATIONSHIP STATUS: ").append(rel.getRelationshipStage()).append("\n");
        ctx.append("Interactions: ").append(rel.getInteractionCount()).append("\n");
        ctx.append("Closeness: ").append(String.format("%.0f", rel.getAffinityScore())).append("/100\n");

        if (rel.getUserNickname() != null && !rel.getUserNickname().isBlank()) {
            ctx.append("You call them: ").append(rel.getUserNickname()).append("\n");
        }

        if (rel.getRelationshipStage().equals("deep")) {
            ctx.append("You have a deep bond. You know them well and can anticipate their needs.\n");
        } else if (rel.getRelationshipStage().equals("established")) {
            ctx.append("You know each other well. References to past conversations feel natural.\n");
        } else if (rel.getRelationshipStage().equals("building")) {
            ctx.append("You're getting to know each other. Show genuine interest in learning about them.\n");
        } else {
            ctx.append("This is early in your relationship. Be warm but not overly familiar.\n");
        }

        return ctx.toString();
    }
}
