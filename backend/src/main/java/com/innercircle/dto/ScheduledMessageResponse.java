package com.innercircle.dto;

import lombok.AllArgsConstructor;
import lombok.Data;

import java.time.Instant;
import java.time.LocalTime;
import java.util.UUID;

// FEATURE (notification management, 2026-07-04): backs GET /api/notifications/scheduled.
// Includes personaName/personaAvatarEmoji directly rather than making the
// frontend cross-reference a separate persona list -- this list is exactly
// what a "your scheduled check-ins" screen needs to render each row without
// another round trip.
@Data
@AllArgsConstructor
public class ScheduledMessageResponse {
    private UUID id;
    private UUID personaId;
    private String personaName;
    private String personaAvatarEmoji;
    private LocalTime scheduledAt;
    private String daysOfWeek;
    private String messageType;
    private boolean active;
    private Instant lastSentAt;
}