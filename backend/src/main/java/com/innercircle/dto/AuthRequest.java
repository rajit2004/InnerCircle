package com.innercircle.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class AuthRequest {
    @NotBlank
    @Email
    @Size(max = 254)
    private String email;

    @NotBlank
    @Size(max = 128) // SECURITY: cap bcrypt input (also avoids silent >72-byte truncation surprises)
    private String password;

    @Size(max = 100)
    private String displayName;

    private String dateOfBirth;
}