package com.innercircle.controller;

import com.innercircle.dto.NotificationRegisterRequest;
import com.innercircle.dto.NotificationScheduleRequest;
import com.innercircle.dto.ScheduledMessageResponse;
import com.innercircle.model.User;
import com.innercircle.service.NotificationService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/notifications")
@RequiredArgsConstructor
public class NotificationController {

    private final NotificationService notificationService;

    @PostMapping("/register")
    public Map<String, String> registerToken(@AuthenticationPrincipal User user,
                                             @Valid @RequestBody NotificationRegisterRequest request) {
        notificationService.registerToken(user, request.getToken(), request.getPlatform());
        return Map.of("status", "registered");
    }

    @PostMapping("/schedule")
    public Map<String, String> scheduleMessage(@AuthenticationPrincipal User user,
                                               @Valid @RequestBody NotificationScheduleRequest request) {
        notificationService.scheduleMessage(
                user,
                request.getPersonaId(),
                request.getScheduledAt(),
                request.getDaysOfWeek(),
                request.getMessageType()
        );
        return Map.of("status", "scheduled");
    }

    // FEATURE (notification management, 2026-07-04): the three endpoints
    // below turn scheduling from write-only into something you can actually
    // manage -- see NotificationService for the corresponding list/cancel/
    // setActive methods.

    @GetMapping("/scheduled")
    public List<ScheduledMessageResponse> listScheduled(@AuthenticationPrincipal User user) {
        return notificationService.listForUser(user);
    }

    @DeleteMapping("/scheduled/{id}")
    public ResponseEntity<Void> cancelScheduled(@AuthenticationPrincipal User user, @PathVariable UUID id) {
        notificationService.cancel(id, user);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/scheduled/{id}/toggle")
    public ScheduledMessageResponse toggleScheduled(@AuthenticationPrincipal User user,
                                                    @PathVariable UUID id,
                                                    @RequestBody Map<String, Boolean> body) {
        boolean active = body.getOrDefault("active", true);
        return notificationService.setActive(id, user, active);
    }
}