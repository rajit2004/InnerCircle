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
import java.util.concurrent.Callable;

@RestController
@RequestMapping("/api/chat")
@RequiredArgsConstructor
public class ChatController {

    private final ChatService chatService;

    // PERF: returns a Callable so Spring MVC executes chatDirect() on its async
    // task executor instead of blocking a Tomcat worker thread while Groq is
    // called (the .block() inside chatDirect would otherwise hold a servlet
    // thread for the full multi-second LLM latency, exhausting the pool under
    // concurrency). Exceptions thrown inside the Callable still propagate to
    // the @ControllerAdvice exception handlers.
    @PostMapping
    public Callable<ResponseEntity<ChatResponse>> chat(@AuthenticationPrincipal User user,
                                                       @Valid @RequestBody ChatRequest request) {
        return () -> ResponseEntity.ok(chatService.chatDirect(request, user));
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

    // FEATURE (clear chat, 2026-07-06): deletes the most recent conversation
    // for the persona so "clear chat" actually wipes server-side history. See
    // ChatService.deleteConversation().
    @DeleteMapping
    public ResponseEntity<Void> clear(@AuthenticationPrincipal User user,
                                      @RequestParam UUID personaId) {
        chatService.deleteConversation(personaId, user);
        return ResponseEntity.noContent().build();
    }

    // FEATURE (message reactions, round 12): sets or clears the reaction on
    // a single message. Body reaction == null clears it -- used when the
    // frontend detects the user tapped the same emoji that's already set.
    @PutMapping("/messages/{messageId}/reaction")
    public ResponseEntity<Void> setReaction(@AuthenticationPrincipal User user,
                                            @PathVariable UUID messageId,
                                            @RequestBody com.innercircle.dto.ReactionRequest request) {
        chatService.setReaction(messageId, request.getReaction(), user);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/test")
    public String test() {
        return "ChatController is alive!";
    }
}