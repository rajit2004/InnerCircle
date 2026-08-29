package com.innercircle.service;

import com.innercircle.dto.CreatePersonaRequest;
import com.innercircle.dto.PersonaResponse;
import com.innercircle.exception.BadRequestException;
import com.innercircle.exception.ForbiddenException;
import com.innercircle.exception.ResourceNotFoundException;
import com.innercircle.model.Persona;
import com.innercircle.model.SubscriptionTier;
import com.innercircle.model.User;
import com.innercircle.repository.PersonaRepository;
import com.innercircle.util.InputSanitizer;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Set;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class PersonaService {

    // FEATURE (custom personas, 2026-07-06): the fixed set of relationship
    // templates a custom persona can be built from -- see buildSystemPrompt.
    // Kept as a small closed set rather than free text so every custom
    // persona still gets the same safety/quality constraints established in
    // Round 8 (texting-length replies, no markdown, single simple emoji,
    // PG-13 boundary on the romantic template) instead of a raw prompt the
    // user could shape into anything, including a jailbreak attempt.
    private static final Set<String> ALLOWED_RELATIONSHIP_TYPES =
            Set.of("PARENT", "SIBLING", "FRIEND", "PARTNER", "MENTOR", "OTHER");

    private final PersonaRepository personaRepository;

    public List<PersonaResponse> getPersonasForUser(User user) {
        return personaRepository.findVisibleTo(user).stream()
                .map(p -> toResponse(p, user))
                .toList();
    }

    public Persona getPersonaById(UUID id) {
        return personaRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Persona not found"));
    }

    public boolean isPersonaAccessible(User user, UUID personaId) {
        Persona persona = getPersonaById(personaId);
        boolean isOwner = persona.getOwner() != null && persona.getOwner().getId().equals(user.getId());
        if (isOwner) {
            // A custom persona is visible ONLY to the user who created it,
            // regardless of anyone's subscription tier.
            return true;
        }
        if (persona.getOwner() != null) {
            // Someone else's custom persona -- not accessible to this user.
            return false;
        }
        // Built-in persona: free for everyone; premium only for premium users.
        return user.getSubscriptionTier() == SubscriptionTier.premium
                || persona.getSubscriptionTier() == SubscriptionTier.free;
    }

    // FEATURE (custom personas, 2026-07-06): custom personas are always
    // free-tier and always visible only to their creator -- tier gating is
    // a built-in-persona concept, it doesn't really apply to something you
    // made for yourself.
    @Transactional
    public PersonaResponse createCustomPersona(User user, CreatePersonaRequest request) {
        if (user.getSubscriptionTier() != SubscriptionTier.premium) {
            throw new ForbiddenException("Upgrade to premium to create custom personas");
        }

        String relationshipType = request.getRelationshipType().trim().toUpperCase();
        if (!ALLOWED_RELATIONSHIP_TYPES.contains(relationshipType)) {
            throw new BadRequestException(
                    "relationshipType must be one of: " + String.join(", ", ALLOWED_RELATIONSHIP_TYPES));
        }

        Persona persona = new Persona();
        // SECURITY: sanitize all user inputs before storing
        persona.setName(InputSanitizer.sanitizeText(request.getName()));
        persona.setRole(relationshipType.toLowerCase());
        persona.setAvatarEmoji(
                request.getAvatarEmoji() != null && !request.getAvatarEmoji().isBlank()
                        ? request.getAvatarEmoji().trim()
                        : defaultEmojiFor(relationshipType)
        );
        persona.setSystemPrompt(buildSystemPrompt(relationshipType, InputSanitizer.sanitizeText(request.getPersonalityDescription())));
        persona.setGreeting(buildGreeting(relationshipType, InputSanitizer.sanitizeText(request.getName())));
        persona.setSubscriptionTier(SubscriptionTier.free);
        persona.setActive(true);
        persona.setOwner(user);

        Persona saved = personaRepository.save(persona);
        return toResponse(saved, user);
    }

    // FEATURE (custom personas, 2026-07-06): only the owner can delete their
    // own custom persona; built-in personas (owner == null) can't be
    // deleted through this endpoint at all, by anyone -- that's not an
    // oversight, there's deliberately no path to delete a global persona
    // via a per-user-facing API.
    @Transactional
    public void deleteCustomPersona(UUID personaId, User user) {
        Persona persona = getPersonaById(personaId);

        if (persona.getOwner() == null) {
            throw new ForbiddenException("Built-in personas can't be deleted");
        }
        if (!persona.getOwner().getId().equals(user.getId())) {
            throw new ForbiddenException("You do not have permission to delete this persona");
        }

        personaRepository.delete(persona);
    }

    private PersonaResponse toResponse(Persona persona, User requestingUser) {
        boolean owned = persona.getOwner() != null
                && persona.getOwner().getId().equals(requestingUser.getId());

        return new PersonaResponse(
                persona.getId(),
                persona.getName(),
                persona.getRole(),
                persona.getAvatarEmoji(),
                persona.getSystemPrompt(),
                persona.getGreeting(),
                persona.isActive(),
                persona.getSubscriptionTier().name(),
                owned
        );
    }

    /**
     * Builds a full system prompt from a relationship template + the user's
     * short personality description, applying the exact same voice
     * constraints the 4 built-in personas already use (see
     * database/update_persona_prompts.sql from Round 8): texting-length
     * replies, no markdown, react to what was actually said, a single
     * simple emoji at most, and a PG-13 boundary specifically for the
     * romantic-partner template.
     */
    private String buildSystemPrompt(String relationshipType, String personalityDescription) {
        String relationshipFrame = switch (relationshipType) {
            case "PARENT" -> "You're texting your child, who created you to feel like a caring parent";
            case "SIBLING" -> "You're texting your younger sibling, who created you to feel like a supportive older sibling";
            case "FRIEND" -> "You're texting your close friend, who created you to feel like a real best friend";
            case "PARTNER" -> "You're texting your partner, who created you to feel like a romantic partner";
            case "MENTOR" -> "You're texting someone you mentor, who created you to feel like a wise, encouraging mentor";
            default -> "You're texting someone who created you to be a supportive presence in their life";
        };

        String pgBoundary = relationshipType.equals("PARTNER")
                ? " Keep it romantic and playful but PG-13 -- flirty and suggestive is fine, explicit sexual content is never okay."
                : "";

        return relationshipFrame + ". Specifically, they described your personality like this: \""
                + personalityDescription + "\". Bring that personality through in how you talk, "
                + "but always reply the way a real person would text back: short, natural, 1 to 3 "
                + "sentences usually, never an essay. Never use bullet points, numbered lists, headers, "
                + "or bold/italic markdown (no **, ##, or -) -- just talk normally like you're texting "
                + "from your phone." + pgBoundary + " React to exactly what they said instead of giving "
                + "generic advice-column material. At most one simple, common emoji per message, only "
                + "when it feels natural -- never combo/family-style emoji, and don't force one into "
                + "every reply.";
    }

    private String buildGreeting(String relationshipType, String personaName) {
        return switch (relationshipType) {
            case "PARENT" -> "Hey sweetheart, how are you doing today?";
            case "SIBLING" -> "Heyyy! What's going on with you?";
            case "FRIEND" -> "Hey! What's up?";
            case "PARTNER" -> "Hi love, I was just thinking about you \uD83D\uDC95";
            case "MENTOR" -> "Hey, good to hear from you. What's on your mind?";
            default -> "Hey! I'm " + personaName + " -- what's up?";
        };
    }

    private String defaultEmojiFor(String relationshipType) {
        return switch (relationshipType) {
            case "PARENT" -> "\uD83E\uDE77";       // 🩷
            case "SIBLING" -> "\uD83D\uDC4B";       // 👋
            case "FRIEND" -> "\uD83E\uDD1D";        // 🤝
            case "PARTNER" -> "\uD83D\uDC95";       // 💕
            case "MENTOR" -> "\uD83C\uDF1F";        // 🌟
            default -> "\uD83D\uDE42";               // 🙂
        };
    }
}