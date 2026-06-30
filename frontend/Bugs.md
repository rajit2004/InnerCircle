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