# FrontendFix.md

This is what I actually changed after going through `bugs.md`. Three files got real logic changes, two got the same small safety fix applied twice. Nothing else in the frontend needed touching — models, auth_service, memory_service, memories_screen, and home_screen were all fine as written.

---

## Fix 1 — Made chat actually work (Bug 1)

This was the big one. The frontend was built against an older version of the backend that streamed chat replies over SSE. The backend doesn't do that anymore — it just sends back one JSON object with `reply` and `conversationId` in it, in one normal response. Nobody had gone back and updated the Flutter side after that backend change, so chat was just... not working. The typing indicator would show up and nothing would ever come back.

**`lib/services/api_client.dart`** — Deleted `streamChat()` entirely. It was built to read the response as a line-by-line SSE stream and look for lines starting with `data: `, which never show up anymore because the backend isn't sending SSE. There's nothing to salvage from that method now that the backend's shape changed, so it's gone rather than patched.

**`lib/services/chat_service.dart`** — Deleted the old `sendMessage()` (the one that called the now-dead `streamChat()`). Kept and renamed what used to be `sendMessageSync()` to just `sendMessage()`, since it's the only chat method now and it was already written correctly — it posts to `/api/chat/sync`, gets back a plain map, done. I didn't have to write new logic here, just remove the broken duplicate and keep the one that was already right.

**`lib/screens/chat_screen.dart`** — Rewrote `_sendMessage()`. It used to be an `await for (chunk in stream)` loop that decoded each chunk as JSON and looked for `content` and `done` fields, building up the reply character-by-character as "chunks" arrived. Now it's just: send the request, get one response back, read `reply` and `conversationId` straight off it, add one message bubble. Much simpler, and it actually matches what the backend sends. I also added the `done`-flag conversation-ID handling into this single response instead of waiting for a stream event that will never come.

I want to flag: this means the chat UI no longer streams text in token-by-token like it visually appeared to before (even though that streaming was already broken and not actually displaying live tokens — it was just stuck on the typing spinner forever). The reply now appears all at once when the backend responds. If real token-by-token streaming is something I want back later, that has to be a backend change first — re-enable SSE on a stack that won't 403 it (Netty/WebFlux instead of Tomcat), and then I can rebuild a real SSE client on the frontend to match. For now, working-but-not-streaming beats broken-and-streaming-looking.

---

## Fix 2 — Stopped a `setState()` crash from being possible in login and register (Bug 2)

**`lib/screens/login_screen.dart`** and **`lib/screens/register_screen.dart`** — Both had the exact same shape: call the async auth method, then unconditionally call `setState()` afterward with no check that the screen was still around. Added `if (!mounted) return;` right after each `await` and before each subsequent `setState()` or `Navigator` call. This is the standard Flutter way to guard against calling `setState` on a widget that's already been torn down. Didn't change any of the actual login/register logic, validators, or UI — just wrapped the post-await calls so they bail out cleanly instead of crashing if the widget's gone.

---

## Fix 3 — Fixed the base URL so the app can actually reach the backend on Android (Bug 3)

**`lib/services/api_client.dart`** — `baseUrl` was hardcoded to `http://localhost:8080`, which is the iOS/macOS value. Since this project has an `android/` folder and is the platform being tested, I changed the constant to `http://10.0.2.2:8080`, which is the special loopback alias the Android emulator provides for reaching the host machine. Left the original comment block above it untouched since it already correctly explains all three cases (Android emulator / iOS or macOS / physical device) — I just made the actual constant match the platform that's relevant right now.

If testing ever moves to iOS simulator or a physical device, this one line needs to change again — it's a single named constant specifically so that's a one-line edit, not a hunt through the codebase.

---

## What I looked at and deliberately left alone

- **`lib/models/user.dart`** — `User.fromJson` doesn't match the backend's actual `AuthResponse` shape (no `id` field exists in what the backend sends), but nothing in the app currently calls `User.fromJson` on a login/register response, so it's dead code right now, not an active bug. Wrote it up in bugs.md instead of guessing at how it should actually be wired up — that's a "do we want JWT-decoded user IDs client-side" product question, not a quick fix.
- **`lib/screens/home_screen.dart`** — `BottomNavigationBar` has no `currentIndex` set, which is technically incorrect Flutter usage but isn't causing visible breakage on the SDK version this project is pinned to. Noted it in bugs.md so it doesn't become a surprise on a future Flutter upgrade.
- **Models, `auth_service.dart`, `memory_service.dart`, `memories_screen.dart`** — read through all of these carefully and didn't find anything wrong. They match the backend's actual response shapes and don't have the streaming/lifecycle issues the other files had.

---

## Files changed in this pass

- `lib/services/api_client.dart`
- `lib/services/chat_service.dart`
- `lib/screens/chat_screen.dart`
- `lib/screens/login_screen.dart`
- `lib/screens/register_screen.dart`

## What I haven't done yet

- Haven't run this through `flutter analyze` or `flutter build` myself in this environment — no Flutter SDK access here, same limitation as the backend's Maven situation. Worth running `flutter pub get && flutter analyze` before trusting this compiles clean, though the changes here are small and don't touch anything structurally unusual (no new dependencies, no new imports beyond what was already there).
- Haven't touched the `User.fromJson` mismatch or the `BottomNavigationBar` `currentIndex` issue — both are written up in bugs.md as deliberate non-fixes, not oversights.