package com.innercircle.dto;

import lombok.AllArgsConstructor;
import lombok.Data;

import java.time.Instant;
import java.util.UUID;

// SECURITY: MemoryController previously returned the raw Memory JPA entity.
// Memory.user is an eager @ManyToOne to User, and Memory.persona.owner is also a
// User -- so serializing the entity walked the whole graph and leaked the owner's
// passwordHash (and reset token) into the JSON response. A dedicated DTO makes
// that structurally impossible regardless of any @JsonIgnore on the entity.
@Data
@AllArgsConstructor
public class MemoryResponse {
    private UUID id;
    private String fact;
    private boolean shared;
    private int importance;
    private Instant lastAccessed;
    private UUID personaId;
    private String personaName;
}
