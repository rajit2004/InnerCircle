# FIXES.md

A running log of bugs caught and fixed across the InnerCircle backend. Most of these came up during local testing, a dependency scan, and a few rounds of IntelliJ review.

---

## Round 1 — Initial audit

### Security

The biggest thing: `SecurityConfig` had `anyRequest().permitAll()` and `JwtAuthFilter` wasn't even in the filter chain. This was clearly a dev shortcut that never got reverted — the entire auth layer was effectively bypassed in production. I put proper JWT enforcement back in place and made sure `CorsConfigurationSource` stayed registered as a bean.

Related to that, `JwtAuthFilter` had a dev bypass hardcoded inside it — it was injecting a fake user (`ranesha@example.com`) for every request to `/api/chat` with no token required. Removed that.

Also went through the IDOR surface:
- Conversation continuity now checks ownership before continuing
- Memory creation prevents assigning facts to other users' personas
- Memory deletion checks that you own the memory before allowing it

### Build system

`pom.xml` had `modelVersion` and `xmlns` set to `4.1.0` — that's Maven 4 syntax. Since nothing here actually uses Maven 4 features and Maven 3.x would reject it outright, I reverted both to the standard `4.0.0`.

Also updated `.mvn/wrapper/maven-wrapper.properties` to point at a stable Maven 3.9.9 release instead of an RC build.

### Exception handling

`AuthService.register()` was throwing a raw `RuntimeException` on duplicate email. A `DuplicateEmailException` and a 409 handler already existed in `GlobalExceptionHandler` — they just weren't being used. Fixed the throw site to use the right exception.

In `ChatService`, the tier-gating and conversation-ownership checks were throwing `UnauthorizedException` (401). These are permission failures, not auth failures — 401 risks clients force-logging the user out. Switched both to `ForbiddenException` (403).

Added `DailyLimitExceededException` (returns 429) to support the daily message cap.

### Memory and pgvector

Added `EmbeddingService` with feature-hashing embeddings (1536 dimensions, L2-normalised). Not a proper semantic model — Groq doesn't offer embeddings — but it produces real vectors that pgvector can search on. Previously the embedding column was just sitting unused.

Implemented a proper native `<=>` cosine-distance query in `MemoryRepository.findRelevantMemories()`. Before this the method was either broken or missing entirely.

`ChatService` and `MemoryService` now retrieve memories relevant to the current message rather than always grabbing the top 3 by importance. Falls back to importance-ranking if no embedded memories exist yet.

`MemoryService.extractAndStoreMemory()` now stores an embedding for every extracted fact so the vector search actually has data to work with.

### Notifications

`NotificationController` was accepting requests and silently discarding them — nothing was being persisted. Added `PushToken` and `ScheduledMessage` entities and their repositories.

`NotificationService` now saves tokens and schedules properly. The `@Scheduled` job reads real rows and sends via FCM's v1 API. The old `fcm.googleapis.com/fcm/send` endpoint (server key auth) was shut down by Google in mid-2024 — using it would have failed outright.

If `FCM_CREDENTIALS_PATH` isn't set, the service logs instead of throwing. That's intentional.

Split `NotificationRequest` into `NotificationRegisterRequest` and `NotificationScheduleRequest`. The old shared DTO forced `/schedule` to require irrelevant fields like `token` and `platform`, and had no `@NotNull` on `scheduledAt` — a clear NPE waiting to happen.

### Schema and misc

- Enforced the daily free-tier cap (50 messages/day) with proper `lastMessageDate` reset logic
- Fixed persona tiers in `schema.sql` — Girlfriend and Big Sister were mistakenly set to `free`, so premium gating never triggered. Restored to `premium`
- Added `last_message_date`, `push_tokens`, and `scheduled_messages` columns to `schema.sql`
- Added a content-safety line to the Girlfriend persona's system prompt
- Added `ForbiddenException` and `DailyLimitExceededException` handlers to `GlobalExceptionHandler`

---

## Round 2 — IntelliJ pass

Caught a few more things after running everything through IntelliJ.

`groq.api-key` in `application.yml` had been hardcoded to the literal string `"my-api-key"`, completely ignoring the `GROQ_API_KEY` env var. Every chat request would have failed Groq auth regardless of what you had set in the shell. Reverted to `${GROQ_API_KEY:your-groq-key}`.

Also swapped `groq.model` off `llama-3.1-8b-instant` — Groq announced that model as deprecated on 2026-06-17 and it was already showing instability. Moved to `openai/gpt-oss-120b`.

Restored the missing `<?xml version="1.0" encoding="UTF-8"?>` declaration at the top of `pom.xml`. Not guaranteed to break a build but non-standard to omit.

Other changes from this pass that were left as-is (they were correct):
- Removed the explicit `hibernate.dialect` — Hibernate 6+ auto-detects it, specifying it explicitly causes a deprecation warning on every startup
- Added `.requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()` and `setMaxAge(3600L)` in `SecurityConfig` so CORS preflight requests aren't blocked by Spring Security
- Added `POST /api/chat/sync` as a convenience endpoint for testing without dealing with SSE

Small note: the comment on `enforceDailyMessageLimit`'s `@Transactional` says `save()` might not flush without it — that's not quite right since Spring Data's `save()` is already self-transactional, but the annotation is harmless and makes the intent explicit.

---

## Round 3 — Dependency vulnerability scan (Mend.io)

### Spring Boot 3.4.2 → 4.1.0

Upgraded `spring-boot-starter-parent` from `3.4.2` to `4.1.0`. The reason every CVE in the scan pointed at transitive deps (Spring Framework 6.2.2, Spring Security 6.4.2, Tomcat 10.1.34, Netty 4.1.117, logback 1.5.16) is that 3.4.2 reached end-of-life on 2025-12-31 — no patches are backported to an EOL line. 4.1.0 is the current actively-supported release and pulls in fixed versions of nearly everything flagged.

I considered 3.5.x as a lower-risk intermediate step, but Spring Boot 3.5 itself hits EOL on 2026-06-30, so it would have been a very short-lived fix.

### PostgreSQL driver pinned to 42.7.7

Pinned `org.postgresql:postgresql` to `42.7.7` explicitly. CVE-2025-49146 affects 42.7.4–42.7.6 (MITM bypass of `channelBinding=require`). Pinned directly rather than relying on Boot's BOM so this fix holds regardless of what the parent manages.

### What was not hand-pinned

Jackson, Netty, Tomcat, Spring Security, httpclient5, json-smart, assertj — all come transitively through the parent BOM. The 4.1.0 upgrade should carry them to patched versions. Don't override them individually unless `mvn dependency:tree` still shows an old version after the upgrade.

> **Note:** Spring Boot 3.4 → 4.1 crosses a major Spring Framework version boundary (6 → 7). The APIs this project uses (`SecurityFilterChain`, `HttpSecurity`, `OncePerRequestFilter`, `CorsConfigurationSource`, `BCryptPasswordEncoder`) have been stable across Spring Security major versions for years so it should compile cleanly, but run `.\mvnw.cmd clean compile` and verify. If the jump causes issues before a deadline, drop the parent to `3.5.16` instead — smaller diff, resolves most of the same CVEs, just shorter support window.

---

## Round 4 — Chat 403 (SSE/Tomcat incompatibility)

### Problem

`POST /api/chat` was returning 403 on every request despite a valid JWT. The server logs showed two requests per call — the first authenticated correctly, the second fired immediately with no token and was rejected.

### Root cause

`ChatController` had `@PostMapping(produces = TEXT_EVENT_STREAM_VALUE)`. SSE clients (browsers, PowerShell's `Invoke-RestMethod`, Android OkHttp) automatically send a reconnect request after the initial connection — and by the SSE spec, that reconnect does not carry the `Authorization` header. Spring Security intercepted the unauthenticated reconnect and returned 403.

This is a fundamental stack mismatch: SSE with Spring Security requires the **reactive Netty stack** (WebFlux), where Security and the SSE pipeline share the same reactive context. This app runs on **Tomcat (servlet stack)** where there's no way to preserve the auth context across the reconnect.

### Fix

**`ChatController.java`** — Removed the SSE endpoint. `POST /api/chat` now returns `application/json` via `chatService.chatDirect()`.

**`ChatService.java`** — Added `chatDirect()` which calls Groq without `"stream": true`, parses the standard JSON response, saves user and assistant messages, and fires memory extraction asynchronously on `Schedulers.boundedElastic()`. The existing `streamChat()` is retained but no longer HTTP-exposed — kept for if the stack is ever migrated to Netty/WebFlux.

### Files changed
- `src/main/java/com/innercircle/controller/ChatController.java`
- `src/main/java/com/innercircle/service/ChatService.java`

---

# Round 5 — Two runtime bugs from real test logs

I ran the app end to end against a real Postgres instance and real requests — this caught two genuine bugs that no amount of static review would've found, since they only showed up at runtime against the actual DB and the actual Jackson engine in use.

## `embedding` column INSERT failure

Every chat message was logging `Memory extraction failed: ... column "embedding" is of type vector but expression is of type character varying`. I traced the cause to `@Column(columnDefinition = "vector(1536)")` on `Memory.embedding` — that annotation only controls DDL (schema generation) and does nothing to change what JDBC type Hibernate actually binds on INSERT. So Hibernate was sending a plain varchar parameter and Postgres rejected it outright. This meant memory storage — the actual point of pgvector in this app — had been silently no-oping on every message until now.

**Fix:** I added `@ColumnTransformer(write = "?::vector", read = "embedding::text")` from Hibernate, which injects an explicit cast into the generated SQL on both write and read, while the Java field stays an ordinary `String`. No extra pgvector-specific Hibernate type library needed.

## `POST /api/notifications/schedule` crashing with a 500

My test sent `daysOfWeek` as a JSON array, but `NotificationScheduleRequest.daysOfWeek` only accepted a plain `String` — Jackson threw `MismatchedInputException: Cannot deserialize value of type java.lang.String from Array value` before the request ever reached the controller.

**Fix:** I added a custom `JsonDeserialize` that accepts either a JSON array of day numbers (`[1,2,3,4,5]`) or a CSV string (`"1,2,3,4,5"`), normalizing both to the CSV format the rest of the app (the DB column, `NotificationService`'s cron-matching logic) expects internally.

## Important catch I made while writing that fix: this app is on Jackson 3, not Jackson 2

The crash stack trace showed `tools.jackson.databind.exc.MismatchedInputException`, not `com.fasterxml.jackson.*`. Spring Boot 4.1 (from Round 3's upgrade) ships **Jackson 3** by default, which renamed almost every package from `com.fasterxml.jackson.*` to `tools.jackson.*` — including in-package annotations like `@JsonDeserialize`, which are *not* covered by Jackson's "shared annotations stay on the old package" exception (only things like `@JsonProperty` get that treatment).

I wrote the custom deserializer with the old package names first, caught it by reading the stack trace closely, and rewrote it using `tools.jackson.*` imports before finalizing. Shipping the `com.fasterxml` version would have compiled fine but done nothing — Spring's actual Jackson 3 engine would silently ignore an annotation from a different package as if it weren't there, and this bug would have looked identically broken even after the "fix."

I deliberately left `ChatService.java` and `MemoryService.java` alone — they instantiate their own private `com.fasterxml.jackson.databind.ObjectMapper` to parse Groq's chat-completion JSON, entirely separate from Spring's request-body deserialization pipeline. That's Jackson 2, coexisting on the classpath alongside Jackson 3 (which Spring Boot 4 explicitly supports, and which `pom.xml` already pulls in via its explicit `com.fasterxml.jackson.core:jackson-databind` dependency). It isn't broken, so I didn't touch it. Consolidating onto one Jackson major version everywhere is worth doing later, deliberately — not as a side effect of chasing this bug.

### Files I changed
- `src/main/java/com/innercircle/model/Memory.java`
- `src/main/java/com/innercircle/dto/NotificationScheduleRequest.java`

---

## What's still pending

- No test files added yet — happy to add them if needed
- Firebase push notifications require a real service-account JSON at `FCM_CREDENTIALS_PATH`. Without it the service degrades gracefully (logs only)
- `test.html` and `body.json` are scratch files left unchanged
- Worth confirming on the next test run: do memory facts now persist with a real `[0.1,0.2,...]`-shaped embedding instead of failing silently, and does `/api/notifications/schedule` now accept an array for `daysOfWeek`?
---

## Round 7 — Added conversation history retrieval (chat history wasn't persisting on the frontend)

This came from testing on a real phone: closing and reopening a chat showed no prior messages, and an in-chat style request ("reply shorter") to the Girlfriend persona appeared to reset after reopening. I traced it back here on the backend side first before realizing the actual fix needed both ends.

**What was missing:** there was no way to fetch a persona's conversation history at all. `ChatController` only exposed `POST /api/chat` (send a message) and `GET /api/chat/test`. Every message-send that didn't include a `conversationId` correctly created a new `Conversation` — that part of `ChatService.chatDirect()` was never wrong — but the frontend had no endpoint to ask "what's the most recent conversation I had with this persona, and what did we say?" so it never had a `conversationId` to send back after a screen reopen. New conversation every time, with zero history in it for Groq to see.

**Fix:**

- **`ConversationRepository.java`** — added `findFirstByUserAndPersonaOrderByUpdatedAtDesc(User, Persona)` to look up the most recent conversation for a given persona.
- **`ChatHistoryResponse.java`** (new) — response DTO: `conversationId` (nullable, if there's no prior conversation) plus a list of `{role, content, createdAt}` message DTOs.
- **`ChatService.java`** — added `getHistory(UUID personaId, User user)`: looks up the persona, finds the most recent conversation (if any), and returns its full message list via `ChatHistoryResponse`.
- **`ChatController.java`** — new `GET /api/chat/history?personaId=X` endpoint wiring the above up.

No changes needed to `chatDirect()` itself — it already handled `conversationId` being present or absent correctly. The gap was purely "there was no way to retrieve one to send back."

### Files changed
- `src/main/java/com/innercircle/repository/ConversationRepository.java`
- `src/main/java/com/innercircle/dto/ChatHistoryResponse.java` (new)
- `src/main/java/com/innercircle/service/ChatService.java`
- `src/main/java/com/innercircle/controller/ChatController.java`

(Frontend changes for this fix are logged in the frontend's `Bugs.md` / `FrontendFixes.md` — `chat_screen.dart`, `chat_service.dart`.)

---

## Round 8 — Personas sounded like an AI assistant, not a person

Got feedback after using the app for real: asking Mom for steak got back a full recipe with headers and bold text, replies were long and structured like ChatGPT answers, and emojis were inconsistent -- sometimes not rendering at all. Went through this as a proper prompt-engineering + backend pass since it needed changes in three places, not one.

### Root cause

The original system prompts described a *role* ("provide thoughtful life advice", "be encouraging") but never told the model *how* to actually talk. Left to its own defaults, Groq's model reached for its trained-in "helpful assistant" voice -- markdown headers, **bold**, numbered steps, long structured answers -- the same way it would answer a question on a help forum. Nothing in the prompt said "you're texting a person," so it never behaved like it. On top of that, `max_tokens` was 300 with no `temperature` set, which gave the model plenty of room to write an essay and no push toward sounding more natural/less formulaic.

### Fix — three layers, so it holds even if one layer doesn't fully work

**1. Rewrote all four persona system prompts** (`update_persona_prompts.sql`, and `schema.sql` for fresh installs). Each one now explicitly:
- Frames the persona as texting a specific person (child / best friend / younger sibling / partner), not "assisting a user"
- Bans markdown formatting outright (no headers, no bold/italic asterisks, no bullet or numbered lists)
- Caps expected reply length at 1-3 sentences unless the user clearly asks for more detail
- Gives each persona the actual distinct voice asked for: Mom stays kind and warm but conversational, not a lecture; Best Friend is brutally honest and casual; Big Sister is protective and pampering with teasing warmth; Girlfriend is flirty and playful, PG-13
- Instructs the model to react to what the user *actually said* instead of defaulting to generic advice-column material (this is the direct fix for the steak-recipe problem)
- Constrains emoji use to at most one simple, common, single-codepoint emoji per message (😊 💕 😂 etc.), explicitly avoiding combo/family-style emoji -- partly for a more natural texting feel, partly because those compound emoji are the ones most likely to render inconsistently across Android devices and fonts (same root class of issue as the mojibake avatar emoji fixed back in Round 6)

**2. Tightened the Groq request parameters** in `ChatService.chatDirect()`:
- `max_tokens` dropped from 300 to 150 -- a hard backstop that physically caps reply length regardless of whether the model fully follows the prompt's length guidance
- Added `temperature: 0.9` (previously unset, falling back to the model's default) to push replies away from safe, repetitive phrasing toward something that reads more like natural conversation

**3. Added a server-side markdown sanitizer** (`stripMarkdown()`) that runs on every reply before it's saved or returned. Strips `**bold**`, `__bold__`, `*italic*`, `#`/`##`/`###` headers, and `-`/`*` bullet or numbered-list markers at the start of a line, then collapses the extra blank lines that kind of formatting tends to leave behind. This is the belt-and-suspenders layer -- prompt instructions are advisory, and the model can still slip into markdown on a longer or more "advice-shaped" reply. Since the frontend renders replies in a plain `Text` widget with no markdown parsing, any leaked formatting was showing up as literal asterisks and hash symbols in the chat bubble, which is exactly what made replies look AI-generated instead of human. Stripping it server-side means the fix holds even when the model doesn't fully comply with the prompt.

### Files changed
- `database/update_persona_prompts.sql` (new, migration for existing DBs)
- `database/schema.sql` (persona seed prompts updated for fresh installs)
- `src/main/java/com/innercircle/service/ChatService.java`

### What to expect after this
"Mom, I want a steak" should get something like *"Ooh nice, want me to make it tonight? 😊"* -- not a recipe. Replies across all four personas should read like real text messages: short, no formatting artifacts, and a voice that actually matches Mom-vs-Best-Friend-vs-Big-Sister-vs-Girlfriend instead of all four sounding like the same generic assistant with a different name on top.

### What I couldn't verify
Emoji *rendering* on your specific device font is outside backend control entirely -- restricting the model to simple single-codepoint emoji reduces the odds of hitting an unsupported glyph, but if a specific emoji still doesn't render, that's an Android/font issue, not something this fix touches. Also haven't run this against a real Groq call in this environment (same Maven/network access limitation as always) -- worth testing a few messages per persona after deploying to confirm the tone lands the way it's meant to; prompt tuning sometimes needs a second pass once you see real replies.
---

## Round — GET /api/users/me for the real profile screen (2026-07-03)

The frontend's profile screen was inferring the user's subscription tier by checking whether `GET /api/personas` happened to include any premium-tier persona — which works today because `PersonaService` already filters premium personas out for free users, but a profile screen shouldn't be built on an indirect guess when the backend can just answer the question it's actually being asked.

**New:** `dto/UserProfileResponse.java` — id, email, displayName, subscriptionTier, messagesUsedToday, dailyMessageLimit (0 = unlimited/premium), lastMessageDate, memberSince.

**New:** `controller/UserController.java` — `GET /api/users/me`, backed by `@AuthenticationPrincipal User`. No `SecurityConfig` change needed — `/api/users/**` already falls under the existing `.anyRequest().authenticated()` rule.

**Changed:** `ChatService.FREE_TIER_DAILY_MESSAGE_LIMIT` — was `private static final`, now `public static final`, so `UserController` can report the exact same limit the backend actually enforces rather than hardcoding `50` a second time somewhere else and risking the two numbers drifting apart if the limit's ever tuned.

**Files changed:** `dto/UserProfileResponse.java` (new), `controller/UserController.java` (new), `service/ChatService.java`

---

## Round 9 — Fixed a broken commit + a real "clear chat doesn't actually clear" bug

### Part 1: the markdown-stripper regex from Round 8 never actually compiled

Pulled the latest zip down and IntelliJ was flagging `ChatService.java` with "Illegal escape character in string literal" on the `MD_BOLD`/`MD_ITALIC`/etc. patterns from the last session. Turned out the file that got committed had the backslashes doubled up wrong -- somewhere between writing the regex and it landing in the file, `\\*` (which Java needs for "match a literal asterisk") had become `\\\\*` in some places, which Java's string literal parser rejects outright as an illegal escape. This was a genuine tooling mishap on my end during the previous session, not something introduced by hand-editing. Rebuilt the whole regex block byte-by-byte and verified the exact backslash count in the actual file bytes (not just what a terminal happens to display, which adds its own layer of escaping and can make correct code look wrong at a glance). Confirmed it now compiles cleanly.

### Part 2: "clear chat" button was lying to you

While reading through `chat_screen.dart` I noticed the trash-can icon's `_clearConversation()` only ever touched local widget state (`_messages.clear()`, `_conversationId = null`) -- it never told the backend anything happened. The problem: a new `Conversation` row only gets created in `ChatService.chatDirect()` the moment you actually send a message. So if you hit "clear," the old conversation just sits there in the DB completely untouched. If you then reopened the chat screen *before* typing anything new, `getHistory()` would go find that same old conversation (it's still the most recent one that exists) and load all the "cleared" messages right back. The clear button was cosmetic -- it worked until you left the screen, then quietly undid itself.

**Fix:**
- `ChatService.deleteConversation(UUID personaId, User user)` -- finds the most recent conversation for that persona and deletes it. Messages cascade-delete at the DB level (`schema.sql` already has `ON DELETE CASCADE` on `messages.conversation_id`), so no manual message cleanup needed.
- `ChatController` -- new `DELETE /api/chat?personaId=X` endpoint.
- Frontend: `chat_service.dart` gets `deleteConversation()`, and `chat_screen.dart`'s clear button now shows a confirmation dialog first (since this is genuinely destructive and irreversible) and awaits the real delete before touching local state.

### Files changed
- `src/main/java/com/innercircle/service/ChatService.java`
- `src/main/java/com/innercircle/controller/ChatController.java`
- (frontend changes logged in `FrontendFixes.md`)

---

## Round 10 — Subscription upgrade flow + full notification management

Two real feature gaps closed, both requested together: there was no way to change your own subscription tier, and notification scheduling was write-only (you could POST a schedule but never see, pause, or cancel one).

### Part 1: Subscription upgrade/downgrade

There's no payment gateway anywhere in this project (no Stripe, no Play Billing), so this is built to be exactly what it honestly is: a direct tier toggle, not a checkout flow pretending to charge a card that was never going to be charged.

- **`SubscriptionUpdateRequest.java`** (new) -- `{ tier: "premium" | "free" }`
- **`UserService.java`** (new) -- `updateSubscriptionTier(User, SubscriptionTier)`, saves directly
- **`UserController.java`** -- new `POST /api/users/subscription`, returns the updated profile in one round trip

No changes needed to `ChatService` or `PersonaService` -- both already check `user.getSubscriptionTier()` live off the entity on every request, so a tier change takes effect on the very next message/persona-list fetch with nothing else to wire up.

### Part 2: Notification (scheduled check-in) management

`NotificationController` previously only had `POST /register` and `POST /schedule` -- there was no way to list what you'd scheduled, cancel one, or pause it without deleting it outright.

- **`ScheduledMessageRepository.java`** -- added `findByUserOrderByScheduledAtAsc(User)`
- **`ScheduledMessageResponse.java`** (new) -- includes `personaName`/`personaAvatarEmoji` directly so the frontend doesn't need a second lookup per row
- **`NotificationService.java`** -- added `listForUser()`, `cancel()`, `setActive()` (pause/resume without deleting), each with an ownership check (`ForbiddenException` if the scheduled message belongs to someone else, matching the pattern already used in `MemoryController`)
- **`NotificationController.java`** -- new `GET /api/notifications/scheduled`, `DELETE /api/notifications/scheduled/{id}`, `POST /api/notifications/scheduled/{id}/toggle`

### Scope boundary worth being explicit about

This closes the *scheduling management* gap completely -- you can now see, create, pause, resume, and cancel check-ins, all backed by real persisted data and enforced server-side by the existing cron job in `NotificationService`. What this does **not** do is wire up actual push delivery to a phone: that requires the frontend to have the `firebase_messaging` package, request notification permission, obtain a real FCM token, and call the already-existing (and already-working) `POST /api/notifications/register`. None of that exists in the Flutter app yet -- it's a separate, scoped follow-up if push notifications actually arriving on-device is the next priority. Right now, a scheduled check-in still fires correctly on time server-side; without a registered token, `NotificationService.sendPush()` just logs it instead of pretending to have delivered something it didn't.

### Files changed
- `src/main/java/com/innercircle/dto/SubscriptionUpdateRequest.java` (new)
- `src/main/java/com/innercircle/service/UserService.java` (new)
- `src/main/java/com/innercircle/controller/UserController.java`
- `src/main/java/com/innercircle/dto/ScheduledMessageResponse.java` (new)
- `src/main/java/com/innercircle/repository/ScheduledMessageRepository.java`
- `src/main/java/com/innercircle/service/NotificationService.java`
- `src/main/java/com/innercircle/controller/NotificationController.java`

(Frontend changes logged in `FrontendFixes.md`.)

---

## Round 11 -- Forgot password + custom personas

Two backend features requested together this round (dark mode was frontend-only and is logged in FrontendFixes.md).

### Part 1: Forgot password

Reset token+expiry live directly on `User` (`resetToken`, `resetTokenExpiresAt`) rather than a separate table -- there's exactly one active reset per account, so a join table would be overhead with no payoff.

- **`User.java`** -- added `resetToken`/`resetTokenExpiresAt` fields
- **`UserRepository.java`** -- added `findByResetToken`
- **`ForgotPasswordRequest.java`** / **`ResetPasswordRequest.java`** (new)
- **`EmailService.java`** (new) -- uses `ObjectProvider<JavaMailSender>` so a missing SMTP config degrades honestly (logs the reset code server-side) instead of throwing, same pattern as Firebase's placeholder config in Round 9
- **`AuthService.java`** -- `forgotPassword()` deliberately returns the identical response whether or not the email matches an account, so the endpoint can't be used to enumerate registered emails; `resetPassword()` checks token match + expiry before allowing the change
- **`AuthController.java`** -- new `POST /api/auth/forgot-password`, `POST /api/auth/reset-password`, both under the existing `permitAll` `/api/auth/**` rule -- no `SecurityConfig` changes needed
- **`pom.xml`** -- added `spring-boot-starter-mail`

One thing worth being explicit about in `application.yml`: I deliberately did *not* add a `spring.mail.host` key with an empty default. Spring Boot's `@ConditionalOnProperty` treats an empty-string-present property as "present," so a `JavaMailSender` bean would get created anyway even with nothing actually configured -- silently breaking the honest-fallback path above. Real SMTP config has to go through actual OS env vars (`SPRING_MAIL_HOST` etc.), which is documented inline in `application.yml`.

### Part 2: Custom personas

`Persona` gets an `owner` field (`ManyToOne User`, `@JsonIgnore`'d so the entity's JSON never risks leaking a password hash through it). Built-in personas keep `owner = null`.

- **`Persona.java`** -- added `owner`
- **`PersonaRepository.java`** -- new `findVisibleTo(user, tiers)`: built-in personas gated by tier (as before) plus the user's own custom personas regardless of tier. Also fixed a latent bug in the old query, which never filtered on `active = true` at all.
- **`CreatePersonaRequest.java`** -- takes `relationshipType` (`PARENT`/`SIBLING`/`FRIEND`/`PARTNER`/`MENTOR`/`OTHER`) and a short `personalityDescription`, not a raw system prompt. A free-text prompt field would let a "custom persona" bypass every voice/safety constraint the built-in personas follow (Round 8's texting-length replies, no markdown, PG-13 boundary for the romantic persona) -- so `PersonaService.buildSystemPrompt()` builds the actual prompt from safe per-relationship-type templates instead, folding the user's description in as flavor rather than as instructions.
- **`PersonaResponse.java`** (new) -- replaces raw entity exposure, adds a computed `owned` boolean the frontend uses to decide whether to show a delete option
- **`BadRequestException.java`** (new) + handler in `GlobalExceptionHandler.java` -- for an invalid `relationshipType`
- **`PersonaService.java`** -- rewritten: `getPersonasForUser`, `createCustomPersona`, `deleteCustomPersona` (checks ownership, throws `ForbiddenException` otherwise), `buildSystemPrompt()`, `buildGreeting()`, `defaultEmojiFor()`
- **`PersonaController.java`** -- `GET /api/personas` now returns `PersonaResponse` instead of the raw entity; added `POST /api/personas` and `DELETE /api/personas/{id}`
- **`migration_round11.sql`** (new) -- adds `profiles.reset_token`, `profiles.reset_token_expires_at`, `personas.owner_user_id` (FK to `profiles`, `ON DELETE CASCADE` so deleting an account cleans up its custom personas). Needs to be run against any existing database -- `database/schema.sql` is already updated for fresh installs.

### Files changed
- `src/main/java/com/innercircle/model/User.java`
- `src/main/java/com/innercircle/repository/UserRepository.java`
- `src/main/java/com/innercircle/dto/ForgotPasswordRequest.java` (new)
- `src/main/java/com/innercircle/dto/ResetPasswordRequest.java` (new)
- `src/main/java/com/innercircle/service/EmailService.java` (new)
- `src/main/java/com/innercircle/service/AuthService.java`
- `src/main/java/com/innercircle/controller/AuthController.java`
- `pom.xml`
- `src/main/java/com/innercircle/model/Persona.java`
- `src/main/java/com/innercircle/repository/PersonaRepository.java`
- `src/main/java/com/innercircle/dto/CreatePersonaRequest.java` (new)
- `src/main/java/com/innercircle/dto/PersonaResponse.java` (new)
- `src/main/java/com/innercircle/exception/BadRequestException.java` (new)
- `src/main/java/com/innercircle/exception/GlobalExceptionHandler.java`
- `src/main/java/com/innercircle/service/PersonaService.java`
- `src/main/java/com/innercircle/controller/PersonaController.java`
- `database/migration_round11.sql` (new -- run this against any existing DB)
- `database/schema.sql` (updated for fresh installs)

(Frontend changes logged in `FrontendFixes.md`.)