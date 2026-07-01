package com.innercircle.controller;

import com.innercircle.dto.MemoryRequest;
import com.innercircle.exception.ForbiddenException;
import com.innercircle.exception.ResourceNotFoundException;
import com.innercircle.model.Memory;
import com.innercircle.model.Persona;
import com.innercircle.model.User;
import com.innercircle.repository.MemoryRepository;
import com.innercircle.repository.PersonaRepository;
import com.innercircle.service.EmbeddingService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/memories")
@RequiredArgsConstructor
public class MemoryController {

    private final MemoryRepository memoryRepository;
    private final PersonaRepository personaRepository;
    private final EmbeddingService embeddingService;

    // FEATURE (shared memory, 2026-07-02): Switched from
    // findByUserAndPersonaOrderByImportanceDesc to
    // findByUserAndPersonaOrSharedOrderByImportanceDesc so that memories
    // marked shared = true from OTHER personas now show up here too, not
    // just facts extracted directly under this persona. This means the
    // Memories tab, when filtered to e.g. Mom, will now actually show
    // "User wants a hamburger" if that fact was shared from a Big Sister
    // conversation -- previously it was invisible unless you queried with
    // no personaId filter at all.
    @GetMapping
    public List<Memory> getMemories(@AuthenticationPrincipal User user,
                                    @RequestParam(required = false) UUID personaId) {
        if (personaId != null) {
            Persona persona = personaRepository.findById(personaId)
                    .orElseThrow(() -> new ResourceNotFoundException("Persona not found"));
            return memoryRepository.findByUserAndPersonaOrSharedOrderByImportanceDesc(user, persona);
        }
        return memoryRepository.findByUserOrderByImportanceDesc(user);
    }

    @PostMapping
    public Memory createMemory(@AuthenticationPrincipal User user,
                               @Valid @RequestBody MemoryRequest request) {
        Persona persona = null;
        if (request.getPersonaId() != null) {
            persona = personaRepository.findById(request.getPersonaId())
                    .orElseThrow(() -> new ResourceNotFoundException("Persona not found"));
        }

        Memory memory = new Memory();
        memory.setUser(user);
        memory.setPersona(persona);
        memory.setFact(request.getFact());
        memory.setShared(request.isShared());
        memory.setEmbedding(embeddingService.toPgVectorLiteral(embeddingService.embed(request.getFact())));
        memory.setImportance(1);
        return memoryRepository.save(memory);
    }

    @DeleteMapping("/{id}")
    public void deleteMemory(@AuthenticationPrincipal User user, @PathVariable UUID id) {
        Memory memory = memoryRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Memory not found"));
        if (!memory.getUser().getId().equals(user.getId())) {
            throw new ForbiddenException("You do not have permission to delete this memory");
        }
        memoryRepository.delete(memory);
    }
}