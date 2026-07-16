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
---

## Fix 4 — Made chat history actually persist across screen reopens (Bug 4)

This was reported two ways that turned out to be one bug: "no older chats after reopening" and "asking Girlfriend to reply shorter stopped working after I reopened the chat." Both came from the same root cause — the frontend had no way to load past messages, and no way to tell the backend "continue the conversation I already had," so every reopen silently started a brand new one.

**`lib/services/chat_service.dart`** — Added `getHistory(personaId)`, which calls the new `GET /api/chat/history?personaId=X` backend endpoint (see `BackendFIXES.md`) and returns the most recent conversation's `conversationId` plus its full message list.

**`lib/screens/chat_screen.dart`** — `initState()` no longer just adds the greeting and stops. It now calls `_loadHistory()` first: fetch whatever conversation already exists for this persona, populate `_messages` from it, and restore `_conversationId` so the next message sent continues that conversation instead of orphaning it in favor of a new one. Added a brief loading spinner while this fetch is in flight, and a fallback to greeting-only if there's no prior conversation or the fetch fails for any reason — didn't want a flaky history load to ever block someone from being able to chat.

This is also what fixes the "style instruction resets" symptom — it was never actually forgotten by the AI, it was just living in a conversation the app had stopped pointing at. Once `_conversationId` correctly survives a reopen, the conversation (and everything said in it) keeps being the one that's continued.

---

## Files changed in this pass

- `lib/services/chat_service.dart`
- `lib/screens/chat_screen.dart`

(Backend changes for this fix are logged separately in `BackendFIXES.md` — `ChatController.java`, `ChatService.java`, `ConversationRepository.java`, new `ChatHistoryResponse.java`.)
---

## Fix 5 — Full visual redesign + splash screen + exit confirmation + real profile data (2026-07-03)

This was a different kind of pass than the bug fixes above — I was asked to actually design the UI/UX properly rather than just patch what was broken, so I went through it the way I'd approach a real design brief: pick a system, build it, then use the app as if I were a first-time customer and fix what felt off.

**What was wrong with the visual design before this:** the app was using Flutter's default `ColorScheme.fromSeed()` theme — one seed color auto-generating every other color in the app. That's fine for getting something on screen fast, but it meant all four personas (Mom, Best Friend, Girlfriend, Big Sister) looked and felt identical before you'd read a single word — same tint everywhere, nothing in the visual language said "this app is about four different people," which is the actual core idea of the product.

**New design system — `lib/theme/app_theme.dart`:** one warm plum brand color for the app shell (buttons, focus states, app bar), plus a distinct accent color per persona used consistently everywhere that persona shows up — avatar, chat bubbles, app bar when you're in their chat. Colors were picked to carry some emotional meaning, not just to look different: terracotta for Mom (warm, grounded), amber for Best Friend (energetic), rose for Girlfriend (soft), teal for Big Sister (steady, protective). Typography switched from the default system font to Poppins (headings) + Inter (body) via `google_fonts`, for a slightly more considered, less "default Android app" feel.

**Custom avatars instead of raw emoji — `lib/widgets/persona_avatar.dart`:** this turned out to matter for a real reason, not just polish. Multi-codepoint emoji rendering depends on the server charset header, the HTTP client's decoding, and the device's emoji font all agreeing — any one link being off produces mojibake (see Bugs.md Bug 5). It also renders differently across OEM Android skins (MIUI's emoji set looks different from stock Android). A gradient circle + vector icon we draw ourselves has none of these failure modes and looks identical on every device.

**Splash screen — `lib/widgets/splash_screen.dart`:** the app already had a brief loading window in `main.dart` while checking for a saved auth token (`FutureBuilder` + `AuthService.isLoggedIn()`) — it was just showing a bare spinner on white during that wait. Swapped in a small branded animation (scale + fade in the logo mark and app name) for the exact same wait that was already happening — no added delay, just gave that moment a face instead of leaving it blank.

**Exit confirmation — `lib/widgets/exit_confirmation_wrapper.dart`:** wraps `HomeScreen` (the bottom of the nav stack) with `PopScope` so the system back button from there shows a "Leaving already?" dialog instead of closing the app instantly. This app holds in-progress conversations; a single accidental back-swipe (very easy on Android gesture nav while scrolling a chat) shouldn't be able to silently kill the app mid-thought.

**Real profile data instead of an inferred guess:** the old profile screen read `subscriptionTier` from `SharedPreferences`, which `HomeScreen` set by *guessing* — checking whether any persona in `GET /api/personas` happened to be premium-tier. That guess is actually correct today (the backend already filters premium personas out for free-tier users), but a profile screen — the one place people go to double-check their account status — shouldn't be built on an indirect inference when the backend can just be asked directly. Added a real `GET /api/users/me` endpoint (backend) and wired the redesigned profile screen to it. Bonus: this also let me add a real "messages used today / 50" usage bar for free-tier users, using the actual constant `ChatService` enforces, so the number shown can't drift from what's actually enforced.

**Other UX passes while going through everything as a "customer":**
- Empty states (no personas, no memories) went from a single line of text to an icon + an explanation of *why* it's empty, so it doesn't read as "is this broken?"
- Typing indicator went from a spinner to three pulsing dots — the pattern people already recognize from every other messaging app, and it reads as "someone is composing a reply" rather than "the app is doing something."
- Chat input's send button now visibly enables (fills with the persona's color) only once there's text to send, instead of always looking tappable.
- Memory deletion now confirms first — see Bugs.md Bug 6.

**Files changed/added (frontend):**
- New: `lib/theme/app_theme.dart`, `lib/widgets/persona_avatar.dart`, `lib/widgets/splash_screen.dart`, `lib/widgets/exit_confirmation_wrapper.dart`, `lib/models/user_profile.dart`, `lib/services/user_service.dart`
- Redesigned (logic preserved, UI rebuilt): `lib/screens/login_screen.dart`, `lib/screens/register_screen.dart`, `lib/screens/home_screen.dart`, `lib/screens/chat_screen.dart`, `lib/screens/memories_screen.dart`, `lib/screens/profile_screen.dart`, `lib/main.dart`
- `pubspec.yaml` — added `google_fonts: ^6.2.1`

**Files changed (backend):** new `UserController.java`, new `dto/UserProfileResponse.java`, `ChatService.java` (made `FREE_TIER_DAILY_MESSAGE_LIMIT` public so the profile endpoint can report the same number instead of a second hardcoded copy) — logged in `BackendFIXES.md` too.

## What I haven't done yet

- Haven't run `flutter pub get && flutter analyze` or `flutter build` myself — no Flutter SDK in this environment, same limitation noted in every prior round. I did a manual brace/paren balance check and cross-checked every model/service method this redesign calls against what actually exists in the project, but that's not a substitute for a real compile. Run `flutter pub get` first (new dependency) then `flutter analyze` before trusting this compiles clean.
- Didn't touch `BottomNavigationBar`/`currentIndex` — not used in the redesigned `HomeScreen` (it uses `NavigationBar`, which was already the pattern here), so this is moot for the touched files, but I didn't go looking for it elsewhere either.
- The splash screen animation is a fixed ~900ms regardless of how long the actual auth check takes — if `AuthService.isLoggedIn()` resolves faster than that on a fast device, the screen still holds for the animation to finish rather than cutting it short. Deliberate (a flash-then-gone splash feels broken), but worth knowing if you ever want it to feel snappier.

---

## Fix 5 — "Clear chat" now actually clears it (Bug 5, see Bugs.md)

Found this one myself while reading through `chat_screen.dart` for the persona-voice work: the trash-can icon in the chat app bar called `_clearConversation()`, which only ever reset local widget state. It never called the backend. Since a conversation only gets created server-side the moment you send a message, hitting "clear" and then leaving the screen without typing anything meant the old conversation was still sitting there untouched -- reopening the chat would silently bring all the "cleared" messages right back via the history-loading fix from a few rounds ago. The button looked like it worked because you don't usually reopen a chat screen within the same second you cleared it.

**`lib/services/chat_service.dart`** -- added `deleteConversation(personaId)`, calling the new `DELETE /api/chat?personaId=X` backend endpoint (see `BackendFIXES.md` Round 9).

**`lib/screens/chat_screen.dart`** -- `_clearConversation()` is now `async`, shows a confirmation dialog first (this is a real, irreversible delete now, not a cosmetic reset -- didn't want a misclick to wipe a conversation with no way back), awaits the actual backend delete, and only then resets local state to show the greeting again.

---

## Files changed in this pass

- `lib/services/chat_service.dart`
- `lib/screens/chat_screen.dart`

(Backend changes logged in `BackendFIXES.md` Round 9 -- `ChatService.java`, `ChatController.java`.)

---

## Fix 6 — Subscription upgrade + check-in reminder management (new features, not bug fixes)

Two feature gaps, both requested together: no way to change your own plan, and no way to manage scheduled check-ins beyond creating them blind and hoping.

**`lib/models/scheduled_message.dart`** (new) -- mirrors the backend's `ScheduledMessageResponse`. Deliberately keeps `daysOfWeek` as the same 1=Sunday..7=Saturday CSV convention the backend uses (matching Postgres `EXTRACT(DOW)`) rather than converting to Dart's own weekday numbering anywhere -- one less place for an off-by-one to sneak in between two systems that don't agree on what day 1 means.

**`lib/services/notification_service.dart`** (new) -- wraps the four notification endpoints (schedule/list/cancel/toggle).

**`lib/services/user_service.dart`** -- added `updateSubscription(tier)`.

**`lib/screens/notifications_screen.dart`** (new) -- lists scheduled check-ins with the persona's avatar (via the existing `PersonaAvatar` widget, not raw emoji -- consistent with why that widget exists at all, see its own doc comment), a switch to pause/resume without deleting, and swipe-free delete with confirmation. Adding a new one opens a bottom sheet: pick a persona from a horizontal avatar row, pick a time via the native time picker, pick days via filter chips. Empty state matches the app's existing pattern (icon + explanation + retry via pull-to-refresh) rather than inventing a new one.

**`lib/screens/profile_screen.dart`** -- added a `_SubscriptionCard` above the existing usage card. Deliberately worded to say plainly that there's no real payment involved, since there's genuinely no billing integration in this app -- didn't want a "Switch to Premium" button that visually implies a checkout is about to happen when it's actually just flipping a database column. Also added a "Check-in reminders" list tile that opens the new notifications screen.

**`lib/main.dart`** -- added the `/notifications` named route for consistency with how the other screens are registered, even though the primary entry point is the Profile screen tile (`Navigator.push`), not the named route.

### What this doesn't do yet
The notifications screen manages *scheduling* only. Actually receiving a check-in as a push notification on the phone needs the `firebase_messaging` package added to `pubspec.yaml`, a permission-request flow, and wiring the resulting token to the already-working `POST /api/notifications/register` -- none of which exists in the app yet. A scheduled check-in still fires correctly on the backend at the right time; it just has nowhere to deliver to until that piece exists. Flagged clearly in the new screen's own doc comment so this isn't a surprise later.

---

## Files changed in this pass

- `lib/models/scheduled_message.dart` (new)
- `lib/services/notification_service.dart` (new)
- `lib/services/user_service.dart`
- `lib/screens/notifications_screen.dart` (new)
- `lib/screens/profile_screen.dart`
- `lib/main.dart`

(Backend changes logged in `BackendFIXES.md` Round 10.)