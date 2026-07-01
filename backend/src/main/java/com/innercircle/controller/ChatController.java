package com.innercircle.controller;

import com.innercircle.dto.ChatHistoryResponse;
import com.innercircle.dto.ChatRequest;
import com.innercircle.dto.ChatResponse;
import com.innercircle.model.User;
import com.innercircle.service.ChatService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/chat")
@RequiredArgsConstructor
public class ChatController {

    private final ChatService chatService;

    @PostMapping
    public ResponseEntity<ChatResponse> chat(@AuthenticationPrincipal User user,
                                             @Valid @RequestBody ChatRequest request) {
        return ResponseEntity.ok(chatService.chatDirect(request, user));
    }

    // FEATURE (chat history, 2026-07-02): new endpoint so the frontend can
    // restore the most recent conversation with a persona when the chat
    // screen is reopened, instead of always starting fresh. See
    // ChatService.getHistory() for the full explanation and bugs.md for how
    // this was discovered (reported as "chats aren't retained" and a style
    // instruction like "reply shorter" appearing to reset -- same root cause).
    @GetMapping("/history")
    public ResponseEntity<ChatHistoryResponse> history(@AuthenticationPrincipal User user,
                                                       @RequestParam UUID personaId) {
        return ResponseEntity.ok(chatService.getHistory(personaId, user));
    }

    @GetMapping("/test")
    public String test() {
        return "ChatController is alive!";
    }
}