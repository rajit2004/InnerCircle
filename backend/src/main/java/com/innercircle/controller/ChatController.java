package com.innercircle.controller;

import com.innercircle.dto.ChatRequest;
import com.innercircle.dto.ChatResponse;
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

    // BUG FIX (Round 6): Removed the SSE streaming endpoint entirely. As documented
    // in BackendFIXES.md Round 4, SSE on Tomcat (servlet stack) causes Spring Security to
    // 403 the client's automatic reconnect request, since the reconnect doesn't carry
    // the Authorization header. POST /api/chat now returns a proper JSON object
    // ({"reply": "..."}) via ChatResponse instead of either a raw SSE stream or a
    // bare string — the latter was the cause of `$chat.reply` resolving to $null in
    // PowerShell tests: Invoke-RestMethod was receiving a plain string body, which
    // has no .reply property, not an object.
    @PostMapping
    public ResponseEntity<ChatResponse> chat(@AuthenticationPrincipal User user,
                                             @Valid @RequestBody ChatRequest request) {
        return ResponseEntity.ok(chatService.chatDirect(request, user));
    }

    @GetMapping("/test")
    public String test() {
        return "ChatController is alive!";
    }
}