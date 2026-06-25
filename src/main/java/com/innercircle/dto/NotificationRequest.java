package com.innercircle.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalTime;

@Data
public class NotificationRequest {
    @NotBlank
    private String token;          // FCM token

    @NotBlank
    private String platform;       // "android" or "ios"

    // For scheduling
    private String personaId;
    private LocalTime scheduledAt;
    private String daysOfWeek;     // e.g. "1,2,3,4,5,6,7"
    private String messageType;    // "check_in", "good_morning", etc.
}