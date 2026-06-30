package com.innercircle.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class NotificationRegisterRequest {
    @NotBlank
    private String token;

    @NotBlank
    private String platform; // "android" or "ios"
}
