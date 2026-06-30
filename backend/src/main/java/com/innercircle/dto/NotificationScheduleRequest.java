package com.innercircle.dto;

import tools.jackson.databind.annotation.JsonDeserialize;
import tools.jackson.databind.ValueDeserializer;
import tools.jackson.databind.DeserializationContext;
import tools.jackson.core.JsonParser;
import tools.jackson.core.JsonToken;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Data
public class NotificationScheduleRequest {
    @NotNull
    private UUID personaId;

    // FIX: previously had no @NotNull -- calling /schedule without this threw
    // a raw NullPointerException at request.getScheduledAt().toString().
    @NotNull
    private LocalTime scheduledAt;

    // BUG FIX: the field used to be a plain String, but a client sending
    // "daysOfWeek": [1,2,3,4,5] (the more natural shape for a list of days)
    // crashed with a 500: "Cannot deserialize value of type java.lang.String
    // from Array value". This custom deserializer accepts either a JSON
    // array of day numbers OR a comma-separated string, and normalizes both
    // to the CSV string the rest of the app (DB column, NotificationService's
    // cron-matching logic) expects internally.
    //
    // IMPORTANT: imports here are tools.jackson.* (Jackson 3), not the older
    // com.fasterxml.jackson.* (Jackson 2). Spring Boot 4.1's actual JSON
    // engine for request-body parsing is Jackson 3 (confirmed by the
    // tools.jackson.databind.* classes in the original crash stack trace) --
    // a Jackson-2-package-flavored @JsonDeserialize would be a different
    // annotation type entirely as far as that engine's reflection scanning
    // is concerned, and would silently be ignored, leaving this bug exactly
    // as broken as before.
    @JsonDeserialize(using = DaysOfWeekDeserializer.class)
    private String daysOfWeek = "1,2,3,4,5,6,7";

    private String messageType = "check_in";

    static class DaysOfWeekDeserializer extends ValueDeserializer<String> {
        @Override
        public String deserialize(JsonParser p, DeserializationContext ctxt) {
            if (p.currentToken() == JsonToken.START_ARRAY) {
                List<String> days = new ArrayList<>();
                while (p.nextToken() != JsonToken.END_ARRAY) {
                    days.add(p.getValueAsString());
                }
                return String.join(",", days);
            }
            // Already a plain string, e.g. "1,2,3,4,5,6,7"
            return p.getValueAsString();
        }
    }
}