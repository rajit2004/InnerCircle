package com.innercircle.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.UUID;

// BUG FIX (Round 6): The old ChatResponse had a single field named `token` left
// over from an earlier draft — it was never actually populated with the chat
// reply anywhere in the codebase (ChatService.processChat() built it with the
// raw reply string but assigned it positionally to the wrong-named field, which
// still compiled fine since @AllArgsConstructor doesn't check field names against
// call-site intent — but any client reading `.token` off the response would have
// gotten the chat reply text, which is deeply misleading naming).
// Renamed to `reply` and added `conversationId` so Android can reuse it for
// continuity. This is also the literal field PowerShell's `$chat.reply` test
// expects to exist.
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ChatResponse {
    private String reply;
    private UUID conversationId;
    // FEATURE (message reactions, round 12): the id of the just-saved
    // assistant message, so the frontend can react to a reply immediately
    // without waiting for the next history fetch. Null on the rare path
    // where Groq returned a blank reply and no Message row was created --
    // see ChatService.chatDirect().
    private UUID messageId;
}