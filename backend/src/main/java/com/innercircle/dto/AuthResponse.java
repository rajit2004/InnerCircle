package com.innercircle.dto;

import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class AuthResponse {
    private String token;
    // BUG FIX: Field was named `userId` in AuthResponse but AuthService was passing
    // user.getEmail() as the second argument and "USER" as the third — meaning the
    // `userId` field was actually receiving the email, and `email` was receiving the
    // role string. This made the response misleading/wrong for any client parsing it.
    // Fix: renamed fields to match what AuthService actually passes: email and role.
    private String email;
    private String role;
}
