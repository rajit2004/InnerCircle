package com.innercircle.controller;

import com.innercircle.dto.NotificationRegisterRequest;
import com.innercircle.dto.NotificationScheduleRequest;
import com.innercircle.model.User;
import com.innercircle.service.NotificationService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

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
}
