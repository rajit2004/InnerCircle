package com.innercircle.dto;

import lombok.AllArgsConstructor;
import lombok.Data;

import java.util.UUID;

// FEATURE (custom personas, 2026-07-06): PersonaController used to return
// the raw Persona JPA entity directly. That was fine while Persona had no
// relation to User at all, but now that it has an `owner` field
// (@ManyToOne User), returning the entity directly risks serializing the
// entire owning User object -- including the password hash -- into an API
// response if @JsonIgnore on that field is ever removed or a mapper
// changes. A dedicated response DTO makes that structurally impossible
// regardless of what happens to the entity later, and gives a clean place
// to add `owned` -- a boolean computed relative to whoever's asking, not a
// column that exists in the database.
@Data
@AllArgsConstructor
public class PersonaResponse {
    private UUID id;
    private String name;
    private String role;
    private String avatarEmoji;
    private String personality;
    private String systemPrompt;
    private String greeting;
    private String voice;
    private boolean active;
    private String subscriptionTier;
    private boolean owned;
    private UUID userId;
}