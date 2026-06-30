package src.main.java.com.innercircle.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

import java.util.UUID;

@Data
public class MemoryRequest {
    @NotBlank
    private String fact;

    private UUID personaId; // null = shared across personas
}