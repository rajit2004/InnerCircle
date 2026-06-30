package src.main.java.com.innercircle.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.UUID;

@Data
public class ChatRequest {
    @NotNull
    private UUID personaId;

    @NotBlank
    private String content;

    private UUID conversationId; // optional – if null, create new
}