# bugs.md

This is my running log of bugs I found while going through the Flutter frontend (`frontend/lib`) line by line. I'm writing it as I go so future-me remembers what I actually saw, not just the cleaned-up fix.

---

## [2026-06-30 19:22 UTC] Bug 1 — Chat is completely broken: frontend expects SSE, backend doesn't send it anymore

**Where:** `lib/services/api_client.dart` → `streamChat()`, `lib/services/chat_service.dart` → `sendMessage()`, `lib/screens/chat_screen.dart` → `_sendMessage()`

**What I saw:**

`api_client.dart`'s `streamChat()` opens a `POST` to `/api/chat` and treats the response as a line-by-line SSE stream — it filters for lines starting with `data: `, strips that prefix, and yields each one as a chunk. `chat_screen.dart` then does `await for (String chunk in stream)`, JSON-decodes each chunk, and expects each one to look like `{"content": "...", "done": false}`, accumulating `content` into the message bubble until it sees `"done": true`.

The problem: I went and checked the backend's own FIXES.md (Round 4 and Round 6), and `/api/chat` was deliberately rewritten months ago to stop doing SSE entirely. It now returns one single JSON object — `{"reply": "...", "conversationId": "..."}` — in one normal HTTP response, no streaming, no `data:` prefix, no `done` flag. The backend team did this on purpose because SSE on Tomcat (the servlet stack this backend runs on) causes Spring Security to reject the client's automatic SSE reconnect with a 403, since the reconnect request doesn't carry the Authorization header.

Nobody updated the Flutter side to match. So right now, every time someone sends a chat message:
1. `streamChat()` makes the POST, gets back `{"reply": "Hey sweetie...", "conversationId": "abc-123"}` as one normal HTTP body
2. It tries to read this as a line-stream and filter for lines starting with `data: ` — there are none, because it's not SSE
3. The `where((line) => line.startsWith('data: '))` filter throws every single line away
4. The stream just closes with zero chunks ever emitted
5. `chat_screen.dart`'s `await for` loop never runs even once
6. `_isTyping` never gets set back to `false` inside the loop (it's only reset in the `catch` block or after the loop, and the loop exits silently with no chunks and no error)
7. The user sees the typing indicator and then... nothing. No reply ever appears.

This is the single biggest thing wrong in the whole frontend — chat is the entire point of the app and it doesn't work at all in its current state. There's actually a `sendMessageSync()` method already sitting in `chat_service.dart` that correctly calls `/api/chat/sync` with a normal POST/JSON expectation, but `chat_screen.dart` isn't using it — it's calling the broken streaming one.

**How I'm fixing it:** Rewriting `api_client.dart` to drop `streamChat()` entirely (it doesn't match what the backend sends anymore) and rewriting `chat_screen.dart` to call the existing `ChatService.sendMessageSync()` instead, which already does the right thing — a plain JSON request/response, parses `reply` and `conversationId` directly off the response map. No more fake streaming logic on a backend that doesn't stream.

---

## [2026-06-30 19:22 UTC] Bug 2 — `setState()` after the widget could already be disposed, in both login and register screens

**Where:** `lib/screens/login_screen.dart` → `_login()`, `lib/screens/register_screen.dart` → `_register()`

**What I saw:**

Both screens follow the same pattern:
```dart
void _login() async {
  if (!_formKey.currentState!.validate()) return;
  setState(() => _loading = true);
  try {
    await AuthService.login(...);
    Navigator.pushReplacementNamed(context, '/home');
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(...);
  }
  setState(() => _loading = false);   // <-- this line
}
```

The `setState(() => _loading = false)` at the very end runs unconditionally after the `await`, with no check that the widget is still mounted. If a user fires off a login request and then, say, backgrounds the app, or somehow the screen gets popped/disposed while that network call is still in flight, this throws `setState() called after dispose()` — a real, crash-producing Flutter error, not just a lint warning. It's an easy one to miss because it only shows up under specific timing, which is exactly why it's worth writing down rather than assuming it'll never happen on a slow network or flaky connection (which, for a mobile app talking to a dev backend on `localhost`/`10.0.2.2`, is not a rare scenario at all).

**How I'm fixing it:** Wrapping the post-await `setState()` calls with `if (!mounted) return;` guards in both screens, which is the standard Flutter pattern for this.

---

## [2026-06-30 19:22 UTC] Bug 3 — `baseUrl` is hardcoded to `localhost`, which silently fails on an Android emulator

**Where:** `lib/services/api_client.dart` → `const String baseUrl = 'http://localhost:8080';`

**What I saw:**

There's actually a comment directly above this line that says exactly what the correct value should be per platform:
```dart
// Android emulator: http://10.0.2.2:8080
// iOS simulator / macOS: http://localhost:8080
// Physical device: http://<your_computer_ip>:8080
const String baseUrl = 'http://localhost:8080';
```

But the actual constant is just hardcoded to the iOS/macOS value. On an Android emulator, `localhost` from inside the emulator resolves to the emulator's own loopback, not the host machine running the Spring Boot backend — so every single API call (login, personas, chat, memories, everything) will fail with a connection error, and there's nothing in the symptoms that points directly at "wrong base URL" unless you already know this Android-emulator-networking quirk. This is exactly the kind of thing that wastes an afternoon if you don't know to look for it.

**How I'm fixing it:** I can't auto-detect "which platform is this running on" reliably from pure Dart without pulling in `dart:io` platform checks (`Platform.isAndroid` etc.), so I'm doing the practical thing: making it a single named constant with a clear comment block, and using the Android emulator value (`10.0.2.2`) as the default since that's the platform mentioned earliest in `pubspec.yaml`'s `android/` folder being present — but I'm leaving it extremely obvious and easy to flip back to `localhost` for iOS/physical-device testing.

---

## [2026-06-30 19:22 UTC] Note (not fixing) — `User.fromJson` doesn't match what the backend actually returns, but it's dead code right now

**Where:** `lib/models/user.dart`

**What I saw:**

`User.fromJson` reads `json['id'] ?? json['sub'] ?? ''`. I checked the backend's `AuthResponse` DTO directly (it's documented in the backend's own FIXES.md) — it only ever returns `{token, email, role}`. There's no `id` field and no `sub` field in that response. So if anything ever called `User.fromJson(loginResponse)`, `id` would always come out as an empty string.

I went and checked every call site of `AuthService.login()` and `AuthService.register()` — both just return the raw decoded JSON `Map<String, dynamic>` and separately store the token via `ApiClient.setToken()`. Nobody actually constructs a `User` object from that response anywhere in the current codebase. So this is a real mismatch, but it's not an active bug yet because the broken path is never executed.

**Why I'm not touching it:** Fixing dead code that nothing calls would be guessing at intent I don't have — do you want `User.id` to come from decoding the JWT's `sub` claim client-side instead? Do you want the backend to add a real `id` field to `AuthResponse`? Either is a reasonable fix but it's a product decision, not a bug fix, so I'm flagging it here and leaving the actual change for a deliberate follow-up rather than bundling it into this pass.

---

## [2026-06-30 19:22 UTC] Note (not fixing) — `BottomNavigationBar` in `home_screen.dart` has no `currentIndex`

**Where:** `lib/screens/home_screen.dart`

**What I saw:**
```dart
bottomNavigationBar: BottomNavigationBar(
items: const [...],
onTap: (index) { ... },
),
```
No `currentIndex` is set. Depending on the exact Flutter SDK version, this can either default silently to index 0 or throw an assertion error in debug mode (`There should be exactly one item with a matching currentIndex`). Since tapping "Memories" navigates away via `Navigator.pushNamed` rather than actually switching the bottom nav state, the missing `currentIndex` hasn't caused a visible problem in testing, but it's a latent SDK-version landmine.

**Why I'm not touching it:** This is cosmetic/structural, not something currently breaking functionality, and I didn't want to bundle a "fix" for something that isn't actually causing an error in the SDK version this project is pinned to (`sdk: ^3.12.2` in `pubspec.yaml`). Flagging it so it's not a surprise later if the Flutter SDK gets upgraded.
---

## [2026-07-02 03:40 UTC] Bug 4 — Chats don't survive closing the screen, and in-chat style requests silently "reset"

**Where:** `lib/screens/chat_screen.dart`

**What I saw (from testing on my phone):**

Two things I reported that turned out to be the same bug: (1) closing a chat and reopening it shows zero history, just the persona's greeting again, and (2) I asked the Girlfriend persona to "reply short and humanly," she did for one message, and then the moment I reopened the chat later she was back to long AI-sounding paragraphs like nothing happened.

**Why it was happening:**

`_messages` and `_conversationId` were plain `StatefulWidget` fields. `initState()` only ever did one thing: add the persona's greeting to `_messages`. There was no fetch of anything from the backend on screen open. So every single time `ChatScreen` gets created — which includes navigating away and back, not just force-closing the app — both fields reset to empty/null.

That second part is the actual reason the "reply shorter" instruction seemed to get forgotten. It wasn't actually forgotten — it was sitting as a real message in a real conversation in the database. But since `_conversationId` reset to `null` on reopen, the very next message sent a request with no `conversationId`, and the backend's `ChatService.chatDirect()` does exactly what it's supposed to when that happens: it creates a **brand new** `Conversation` row. That new conversation has zero messages in it, so when it builds the context sent to Groq, there's nothing in there telling the model to keep replies short. The old conversation with that instruction still exists in the DB, just orphaned — nothing was pointing at it anymore.

I also checked the backend directly: there was no endpoint to fetch past messages at all. `ChatController` only had `POST /api/chat` and `GET /api/chat/test`. So even if the frontend had wanted to load history, there was nowhere to load it from.

**How I'm fixing it:** This needed a matching change on both sides, logged here and in `BackendFIXES.md`:

- **Backend:** new `GET /api/chat/history?personaId=X` endpoint that finds the most recent conversation for that user+persona pair and returns its full message list plus the `conversationId`.
- **Frontend:** `initState()` now calls this endpoint first. If a conversation exists, it loads all the past messages into `_messages` and restores `_conversationId` so the *next* message sent continues the same conversation instead of starting a new one. Only falls back to greeting-only if there's genuinely no prior conversation (or the fetch fails for some reason — I didn't want a flaky history fetch to block the chat from being usable at all).

Once `_conversationId` is correctly restored on reopen, style instructions like "reply shorter" stop appearing to reset, because the conversation they're part of is the one still being continued, not orphaned in favor of a fresh one.

**Files changed (frontend):** `lib/screens/chat_screen.dart`, `lib/services/chat_service.dart`
**Files changed (backend):** see `BackendFIXES.md` — `ChatController.java`, `ChatService.java`, `ConversationRepository.java`, new `ChatHistoryResponse.java`
---

## [2026-07-03] Bug 5 — Emoji/mojibake in persona names (the ðŸ‘© thing)

**Where:** `lib/services/api_client.dart`

**What I saw:** the persona list screen showed garbage characters instead of the avatar emoji — `ðŸ'©` instead of `👩`, that kind of thing. I'd already fixed this once on the backend side (added `?characterEncoding=UTF-8&useUnicode=true` to the JDBC URL a few rounds back), and it helped, but the mojibake came back.

**Why it was actually happening:** the backend fix was real and necessary, but it wasn't the whole story. Dart's `http` package decodes `response.body` using whatever charset is declared in the response's `Content-Type` header — and if the server doesn't explicitly declare one, it silently falls back to **Latin-1**. Spring's default `application/json` response often doesn't include an explicit `charset=UTF-8` in the header even when the JSON body itself is correctly UTF-8 encoded on the wire. So the bytes arriving at the phone were correct the whole time — the frontend was just decoding them wrong.

This is a genuinely easy trap: `response.body` *looks* like the obviously-correct thing to read, and it works fine for plain ASCII, so it's easy to never notice until something non-ASCII shows up.

**How I fixed it:** `_handleResponse()` now reads `response.bodyBytes` and decodes it with `utf8.decode()` explicitly, instead of trusting `response.body`'s charset guess. This makes the frontend correct regardless of what charset (if any) the backend declares — belt-and-suspenders with the JDBC fix, but this one is the part that was actually still broken.

**Files changed:** `lib/services/api_client.dart`

---

## [2026-07-03] Bug 6 — Deleting a memory happened instantly, no confirmation

**Where:** `lib/screens/memories_screen.dart`

**What I saw (thinking like someone actually using this):** the delete icon on a memory card fired `MemoryService.deleteMemory()` the moment you tapped it. In a scrolling list, that's one mis-tap away from permanently losing something the AI learned about you in conversation, with zero chance to undo.

**How I fixed it:** added a confirmation dialog (same pattern as logout) before the delete call actually fires. Also added a small snackbar confirming "Memory forgotten" after a successful delete, since silently removing a row from a list with no acknowledgment reads as "did that actually work?"

**Files changed:** `lib/screens/memories_screen.dart`
