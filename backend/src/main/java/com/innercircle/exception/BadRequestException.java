package com.innercircle.exception;

// FEATURE (custom personas, 2026-07-06): for client-input problems that
// aren't a 404 (nothing's missing), a 403 (nothing's forbidden), or a
// framework-level @Valid failure (the value is syntactically fine, just
// not one of the allowed options) -- e.g. relationshipType being a string
// that doesn't match any of PersonaService's known templates. Maps to 400
// via GlobalExceptionHandler.
public class BadRequestException extends RuntimeException {
    public BadRequestException(String message) {
        super(message);
    }
}