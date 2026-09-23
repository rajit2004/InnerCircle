package com.innercircle.exception;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.core.MethodParameter;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.BeanPropertyBindingResult;
import org.springframework.validation.BindingResult;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;

import java.lang.reflect.Method;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class GlobalExceptionHandlerTest {

    private GlobalExceptionHandler handler;

    @BeforeEach
    void setUp() {
        handler = new GlobalExceptionHandler();
    }

    private static MethodArgumentNotValidException validationEx(BindingResult result) {
        try {
            Method m = GlobalExceptionHandler.class.getDeclaredMethod(
                    "handleValidation", MethodArgumentNotValidException.class);
            MethodParameter parameter = new MethodParameter(m, -1);
            return new MethodArgumentNotValidException(parameter, result);
        } catch (NoSuchMethodException e) {
            throw new IllegalStateException(e);
        }
    }

    @Test
    void validationFailureReturns400WithFieldMessage() {
        BindingResult result = new BeanPropertyBindingResult(new Object(), "authRequest");
        result.addError(new FieldError("authRequest", "email", "must be a well-formed email address"));

        ResponseEntity<Map<String, String>> response = handler.handleValidation(validationEx(result));

        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        assertTrue(response.getBody().get("error").contains("email"));
        assertTrue(response.getBody().get("error").contains("must be a well-formed email address"));
    }

    @Test
    void emptyValidationStillReturns400() {
        BindingResult result = new BeanPropertyBindingResult(new Object(), "req");

        ResponseEntity<Map<String, String>> response = handler.handleValidation(validationEx(result));

        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        assertEquals("Validation failed", response.getBody().get("error"));
    }

    @Test
    void badRequestReturns400() {
        ResponseEntity<Map<String, String>> response =
                handler.handleBadRequest(new BadRequestException("Avatar file type not allowed"));
        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        assertEquals("Avatar file type not allowed", response.getBody().get("error"));
    }

    @Test
    void nullMessageUsesFallback() {
        ResponseEntity<Map<String, String>> response =
                handler.handleBadRequest(new BadRequestException(null));
        assertEquals("Bad request", response.getBody().get("error"));
    }

    @Test
    void unauthorizedReturns401() {
        ResponseEntity<Map<String, String>> response =
                handler.handleUnauthorized(new UnauthorizedException("Invalid credentials"));
        assertEquals(HttpStatus.UNAUTHORIZED, response.getStatusCode());
    }

    @Test
    void forbiddenReturns403() {
        ResponseEntity<Map<String, String>> response =
                handler.handleForbidden(new ForbiddenException(null));
        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        assertEquals("Forbidden", response.getBody().get("error"));
    }

    @Test
    void dailyLimitReturns429() {
        ResponseEntity<Map<String, String>> response =
                handler.handleDailyLimit(new DailyLimitExceededException("Daily limit reached"));
        assertEquals(HttpStatus.TOO_MANY_REQUESTS, response.getStatusCode());
        assertEquals("Daily limit reached", response.getBody().get("error"));
    }

    @Test
    void tooManyRequestsReturns429() {
        ResponseEntity<Map<String, String>> response =
                handler.handleTooManyRequests(new TooManyRequestsException("Slow down"));
        assertEquals(HttpStatus.TOO_MANY_REQUESTS, response.getStatusCode());
    }

    @Test
    void genericExceptionReturns500WithoutLeakingMessage() {
        ResponseEntity<Map<String, String>> response =
                handler.handleGeneric(new RuntimeException("password=hunter2 stacktrace..."));
        assertEquals(HttpStatus.INTERNAL_SERVER_ERROR, response.getStatusCode());
        assertEquals("An unexpected error occurred", response.getBody().get("error"));
        assertFalse(response.getBody().get("error").contains("hunter2"));
    }

    @Test
    void duplicateEmailReturns409() {
        ResponseEntity<Map<String, String>> response =
                handler.handleDuplicate(new DuplicateEmailException("Account already exists"));
        assertEquals(HttpStatus.CONFLICT, response.getStatusCode());
    }

    @Test
    void notFoundReturns404() {
        ResponseEntity<Map<String, String>> response =
                handler.handleNotFound(new ResourceNotFoundException("Persona not found"));
        assertEquals(HttpStatus.NOT_FOUND, response.getStatusCode());
    }
}
