package com.innercircle.exception;

import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

import java.util.HashMap;
import java.util.Map;

@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    // SECURITY/BUG FIX: @Valid failures previously fell through to the generic
    // Exception handler and returned HTTP 500 "An unexpected error occurred"
    // with no field-level detail. Clients could not distinguish a validation
    // error from a server crash. This maps bean-validation failures to 400
    // with the offending field and message.
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, String>> handleValidation(MethodArgumentNotValidException ex) {
        Map<String, String> errors = new HashMap<>();
        for (FieldError fe : ex.getBindingResult().getFieldErrors()) {
            errors.putIfAbsent(fe.getField(), fe.getDefaultMessage());
        }
        String message = errors.isEmpty()
                ? "Validation failed"
                : errors.entrySet().iterator().next().getKey() + ": " + errors.entrySet().iterator().next().getValue();
        log.warn("Validation failed: {}", errors);
        return ResponseEntity.badRequest().body(Map.of("error", message));
    }

    // SECURITY: concurrent duplicate registrations hit the UNIQUE(email)
    // constraint after the check-then-insert race — map to 409, not 500.
    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<Map<String, String>> handleDataIntegrity(DataIntegrityViolationException ex) {
        log.warn("Data integrity violation: {}", ex.getMessage());
        return ResponseEntity
                .status(HttpStatus.CONFLICT)
                .body(Map.of("error", "An account with this email already exists"));
    }

    // Malformed JSON body → 400, not 500
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<Map<String, String>> handleUnreadable(HttpMessageNotReadableException ex) {
        log.warn("Malformed request body: {}", ex.getMessage());
        return ResponseEntity.badRequest().body(Map.of("error", "Malformed request body"));
    }

    // Type-mismatch on request params/path (e.g. malformed UUID in ?personaId=) → 400
    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public ResponseEntity<Map<String, String>> handleTypeMismatch(MethodArgumentTypeMismatchException ex) {
        log.warn("Invalid parameter {}: {}", ex.getName(), ex.getValue());
        return ResponseEntity.badRequest().body(Map.of("error", "Invalid parameter: " + ex.getName()));
    }

    // IllegalStateException thrown by controllers (e.g. avatar upload size checks) → 400
    @ExceptionHandler(IllegalStateException.class)
    public ResponseEntity<Map<String, String>> handleIllegalState(IllegalStateException ex) {
        log.warn("Illegal state: {}", ex.getMessage());
        return ResponseEntity.badRequest().body(Map.of("error", safeMessage(ex.getMessage(), "Invalid request")));
    }

    @ExceptionHandler(DuplicateEmailException.class)
    public ResponseEntity<Map<String, String>> handleDuplicate(DuplicateEmailException ex) {
        return ResponseEntity
                .status(HttpStatus.CONFLICT)
                .body(Map.of("error", safeMessage(ex.getMessage(), "Account already exists")));
    }

    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<Map<String, String>> handleNotFound(ResourceNotFoundException ex) {
        return ResponseEntity
                .status(HttpStatus.NOT_FOUND)
                .body(Map.of("error", safeMessage(ex.getMessage(), "Resource not found")));
    }

    @ExceptionHandler(UnauthorizedException.class)
    public ResponseEntity<Map<String, String>> handleUnauthorized(UnauthorizedException ex) {
        return ResponseEntity
                .status(HttpStatus.UNAUTHORIZED)
                .body(Map.of("error", safeMessage(ex.getMessage(), "Unauthorized")));
    }

    @ExceptionHandler(ForbiddenException.class)
    public ResponseEntity<Map<String, String>> handleForbidden(ForbiddenException ex) {
        return ResponseEntity
                .status(HttpStatus.FORBIDDEN)
                .body(Map.of("error", safeMessage(ex.getMessage(), "Forbidden")));
    }

    @ExceptionHandler(DailyLimitExceededException.class)
    public ResponseEntity<Map<String, String>> handleDailyLimit(DailyLimitExceededException ex) {
        return ResponseEntity
                .status(HttpStatus.TOO_MANY_REQUESTS)
                .body(Map.of("error", safeMessage(ex.getMessage(), "Daily limit exceeded")));
    }

    // FEATURE (custom personas, 2026-07-06): relationshipType is a string,
    // not an enum in the request DTO, so an invalid value reaches PersonaService
    // as a plain string. That method throws BadRequestException → 400.
    @ExceptionHandler(BadRequestException.class)
    public ResponseEntity<Map<String, String>> handleBadRequest(BadRequestException ex) {
        return ResponseEntity
                .status(HttpStatus.BAD_REQUEST)
                .body(Map.of("error", safeMessage(ex.getMessage(), "Bad request")));
    }

    @ExceptionHandler(TooManyRequestsException.class)
    public ResponseEntity<Map<String, String>> handleTooManyRequests(TooManyRequestsException ex) {
        return ResponseEntity
                .status(HttpStatus.TOO_MANY_REQUESTS)
                .body(Map.of("error", safeMessage(ex.getMessage(), "Too many requests")));
    }

    // Generic catch-all — keep last so specific handlers take priority
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, String>> handleGeneric(Exception ex) {
        log.error("Unhandled exception", ex);
        return ResponseEntity
                .status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(Map.of("error", "An unexpected error occurred"));
    }

    // SECURITY: Map.of throws NPE if a value is null — never pass ex.getMessage() directly
    private static String safeMessage(String message, String fallback) {
        return (message == null || message.isBlank()) ? fallback : message;
    }
}
