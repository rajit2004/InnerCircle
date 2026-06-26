package com.innercircle.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalTime;
import java.util.UUID;

@Data
public class NotificationScheduleRequest {
    @NotNull
    private UUID personaId;

    // FIX: previously had no @NotNull -- calling /schedule without this threw
    // a raw NullPointerException at request.getScheduledAt().toString().
    @NotNull
    private LocalTime scheduledAt;

    private String daysOfWeek = "1,2,3,4,5,6,7";
    private String messageType = "check_in";
}
