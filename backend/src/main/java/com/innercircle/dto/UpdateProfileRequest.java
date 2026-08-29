package com.innercircle.dto;

import jakarta.validation.constraints.Size;
import lombok.Data;

import java.time.LocalDate;

@Data
public class UpdateProfileRequest {
    @Size(min = 1, max = 100, message = "Display name must be between 1 and 100 characters")
    private String displayName;

    private LocalDate dateOfBirth;

    @Size(min = 2, max = 10, message = "Language must be 2-10 characters")
    private String language;

    @Size(min = 2, max = 50, message = "Timezone must be 2-50 characters")
    private String timezone;
}
