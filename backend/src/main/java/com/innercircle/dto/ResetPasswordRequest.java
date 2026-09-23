package com.innercircle.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class ResetPasswordRequest {
    @NotBlank
    @Size(max = 128)
    private String token;

    @NotBlank
    @Size(min = 8, max = 128, message = "Password must be between 8 and 128 characters")
    private String newPassword;
}