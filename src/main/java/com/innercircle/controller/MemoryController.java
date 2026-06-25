package com.innercircle.controller;

import com.innercircle.dto.MemoryRequest;
import com.innercircle.exception.ForbiddenException;
import com.innercircle.exception.ResourceNotFoundException;
import com.innercircle.model.Memory;
import com.innercircle.model.Persona;
import com.innercircle.model.User;
import com.innercircle.repository.MemoryRepository;
import com.innercircle.repository.PersonaRepository;
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

    @GetMapping
    public List<Memory> getMemories(@AuthenticationPrincipal User user,
                                    @RequestParam(required = false) UUID personaId) {
        if (personaId != null) {
            Persona persona = personaRepository.findById(personaId)
                    .orElseThrow(() -> new ResourceNotFoundException("Persona not found"));
            return memoryRepository.findByUserAndPersonaOrderByImportanceDesc(user, persona);
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
        memory.setImportance(1);
        return memoryRepository.save(memory);
    }

    // BUG FIX: There was no DELETE endpoint for memories, but the Memory model
    // has a full lifecycle. Without this, users have no way to remove memories
    // via the API. Also added an ownership check to prevent users from deleting
    // other users' memories (IDOR vulnerability).
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
