package com.innercircle.controller;

import com.innercircle.dto.CreatePersonaRequest;
import com.innercircle.dto.PersonaResponse;
import com.innercircle.model.User;
import com.innercircle.service.PersonaService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/personas")
@RequiredArgsConstructor
public class PersonaController {

    private final PersonaService personaService;

    @GetMapping
    public List<PersonaResponse> getPersonas(@AuthenticationPrincipal User user) {
        return personaService.getPersonasForUser(user);
    }

    // FEATURE (custom personas, 2026-07-06): builds a persona from a
    // relationship template + short personality description -- see
    // PersonaService.buildSystemPrompt for why this isn't a raw free-text
    // system prompt field.
    @PostMapping
    public PersonaResponse createPersona(@AuthenticationPrincipal User user,
                                         @Valid @RequestBody CreatePersonaRequest request) {
        return personaService.createCustomPersona(user, request);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deletePersona(@AuthenticationPrincipal User user, @PathVariable UUID id) {
        personaService.deleteCustomPersona(id, user);
        return ResponseEntity.noContent().build();
    }
}