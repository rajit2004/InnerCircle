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

## What's still pending

- No test files added yet — happy to add them if needed
- Firebase push notifications require a real service-account JSON at `FCM_CREDENTIALS_PATH`. Without it the service degrades gracefully (logs only)
- `test.html` and `body.json` are scratch files left unchanged