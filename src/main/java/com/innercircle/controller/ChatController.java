package com.innercircle.controller;

import com.innercircle.dto.ChatRequest;
import com.innercircle.model.User;
import com.innercircle.service.ChatService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Flux;

@RestController
@RequestMapping("/api/chat")
@RequiredArgsConstructor


public class ChatController {

    private final ChatService chatService;

    // BUG FIX: ChatController was completely hollow — it had no POST /api/chat endpoint,
    // only a dummy GET /api/chat/test. ChatService.streamChat() existed and worked but
    // was never wired to any HTTP route, making the entire chat feature unreachable.
    // Fix: add the streaming POST endpoint that connects the controller to ChatService.
    @PostMapping(produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public Flux<String> chat(@AuthenticationPrincipal User user,
                             @Valid @RequestBody ChatRequest request) {
        return chatService.streamChat(request, user);
    }

    @PostMapping("/sync")
    public ResponseEntity<String> chatSync(@AuthenticationPrincipal User user,
                                           @Valid @RequestBody ChatRequest request) {
        String reply = chatService.streamChat(request, user)
                .collectList()
                .block()
                .stream()
                .reduce("", String::concat);
        return ResponseEntity.ok(reply);
    }

    // Keep the test endpoint for health-checking the controller
    @GetMapping("/test")
    public String test() {
        return "ChatController is alive!";
    }
}
