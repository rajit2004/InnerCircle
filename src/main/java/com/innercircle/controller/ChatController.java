package com.innercircle.controller;

import com.innercircle.dto.ChatRequest;
import com.innercircle.model.User;
import com.innercircle.service.ChatService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/chat")
@RequiredArgsConstructor
public class ChatController {

    private final ChatService chatService;

    // FIX: Removed the SSE streaming POST endpoint (produces = TEXT_EVENT_STREAM_VALUE).
    // When Tomcat (servlet container) serves SSE, the browser/client sends a follow-up
    // reconnect request without the Authorization header, which Spring Security rejects
    // with 403. SSE works correctly with Netty (reactive stack), not Tomcat.
    // Since this app runs on Tomcat, the chat endpoint must return a regular JSON response.
    // The /sync endpoint below is the correct implementation for this stack.
    @PostMapping
    public ResponseEntity<String> chat(@AuthenticationPrincipal User user,
                                       @Valid @RequestBody ChatRequest request) {
        return ResponseEntity.ok(chatService.chatDirect(request, user));
    }

    @GetMapping("/test")
    public String test() {
        return "ChatController is alive!";
    }
}