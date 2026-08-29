package com.innercircle.controller;

import com.innercircle.model.User;
import com.innercircle.model.UserPreferences;
import com.innercircle.repository.UserPreferencesRepository;
import jakarta.validation.Valid;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/user-preferences")
@RequiredArgsConstructor
public class UserPreferencesController {

    private final UserPreferencesRepository userPreferencesRepository;

    @GetMapping
    public UserPreferences getPreferences(@AuthenticationPrincipal User user) {
        return userPreferencesRepository.findByUserId(user.getId())
                .orElseGet(() -> {
                    UserPreferences prefs = new UserPreferences();
                    prefs.setUserId(user.getId());
                    prefs.setUser(user);
                    return userPreferencesRepository.save(prefs);
                });
    }

    @PutMapping
    public UserPreferences updatePreferences(@AuthenticationPrincipal User user,
                                             @Valid @RequestBody UpdatePreferencesRequest request) {
        UserPreferences prefs = userPreferencesRepository.findByUserId(user.getId())
                .orElseGet(() -> {
                    UserPreferences newPrefs = new UserPreferences();
                    newPrefs.setUserId(user.getId());
                    newPrefs.setUser(user);
                    return userPreferencesRepository.save(newPrefs);
                });

        if (request.getPreferredName() != null) prefs.setPreferredName(request.getPreferredName());
        if (request.getCommunicationStyle() != null) prefs.setCommunicationStyle(request.getCommunicationStyle());
        if (request.getResponseLength() != null) prefs.setResponseLength(request.getResponseLength());
        if (request.getInterests() != null) prefs.setInterests(request.getInterests());
        if (request.getGoals() != null) prefs.setGoals(request.getGoals());
        prefs.setMemoryEnabled(request.isMemoryEnabled());

        return userPreferencesRepository.save(prefs);
    }

    @Data
    public static class UpdatePreferencesRequest {
        private String preferredName;
        private String communicationStyle;
        private String responseLength;
        private String interests;
        private String goals;
        private boolean memoryEnabled = true;
    }
}
