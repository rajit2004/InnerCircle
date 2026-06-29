# Fixes applied

I've been going through the codebase and fixing a bunch of issues that were either broken, incomplete, or just not working the way they should. Here's a rundown of everything I did.

---

## Security stuff

First, I had to deal with a pretty serious security hole – the auth bypass that was left in place during development. `SecurityConfig` had been set to `anyRequest().permitAll()`, and `JwtAuthFilter` wasn't even registered in the filter chain. I put everything back the way it should be: real JWT enforcement is now active, and I made sure the `CorsConfigurationSource` bean stayed in place.

I also removed the dev bypass from `JwtAuthFilter` itself. That thing was injecting a hardcoded fake user (`ranesha@example.com`) for every request to `/api/chat` – no token required. That's obviously not something I wanted to keep around.

I went through and verified the IDOR fixes too. Conversation continuity now actually checks ownership, memory creation doesn't let you assign things you shouldn't, and deleting memory also checks that you actually own it.

---

## Build system

The build setup needed some attention too. `pom.xml` had `modelVersion` and `xmlns` set to `4.1.0`, which is a Maven 4 thing. But nothing in this project actually uses any Maven 4 features, and regular Maven 3.x would just reject it. So I reverted it back to the standard `4.0.0`.

While I was at it, I also updated `.mvn/wrapper/maven-wrapper.properties` to point back to a stable Maven 3.9.9 release instead of some RC build of Maven 4.

---

## Exceptions and status codes

The exception handling was a bit of a mess. In `AuthService.register()`, I was just throwing a raw `RuntimeException` when a duplicate email was detected. But I already had a `DuplicateEmailException` and a 409 handler for it – it just wasn't being used. I fixed that so the proper exception gets thrown now.

In `ChatService`, I changed the tier-gating and conversation-ownership checks to throw `ForbiddenException` (which gives a 403) instead of `UnauthorizedException` (401). These are permission issues, not authentication failures, so 401 would have risked the client force-logging the user out unnecessarily.

I also added a new `DailyLimitExceededException` (returns 429) to support the daily message cap.

---

## Memory and pgvector

This was a big one. I added an `EmbeddingService` that does feature-hashing embeddings (1536 dimensions, L2-normalised). It's not a proper semantic model – Groq doesn't offer embeddings – but it's a real, working vector that pgvector can actually search on. Before this, the embedding column was just sitting there unused.

I implemented a proper native `<=>` cosine-distance query in `MemoryRepository.findRelevantMemories()`. Before, it was either broken or non-existent.

The big improvement: `MemoryService` and `ChatService` now retrieve memories that are actually relevant to the current message, instead of just grabbing the "top 3 most important ever." If there aren't any embedded memories yet, it falls back to importance-ranking.

`MemoryService.extractAndStoreMemory()` now stores an embedding for every fact it extracts, so the vector search actually has data to work with.

---

## Notifications

This was basically non-functional before. The `NotificationController` was accepting data and just... discarding it. I added `PushToken` and `ScheduledMessage` entities along with their repositories so there's actually somewhere to store things.

`NotificationService` now persists tokens and schedules properly, and the `@Scheduled` job actually reads real rows from the database and sends pushes using FCM's current v1 API. The legacy endpoint (`fcm.googleapis.com/fcm/send` with server keys) was shut down by Google in mid-2024, so the old approach would've failed outright.

If no Firebase service-account JSON is configured (via `FCM_CREDENTIALS_PATH`), it logs instead of pretending to send. You need to set that env var to a real service-account file to enable actual delivery.

I also split the bloated `NotificationRequest` DTO into two separate ones: `NotificationRegisterRequest` and `NotificationScheduleRequest`. The old shared DTO forced `/schedule` to require irrelevant fields like `token` and `platform`, and it had no `@NotNull` on `scheduledAt` – a clear NPE risk.

---

## Other improvements

I enforced the daily free-tier cap (50 messages per day). It now actually checks `User.lastMessageDate` and `messagesUsedToday`, with proper reset logic when a new day starts.

In `schema.sql`, I fixed the persona tiers – Girlfriend and Big Sister were set to `free`, which meant the tier-gating code never actually triggered. I restored them to `premium`. I also added columns for `last_message_date`, `push_tokens`, and `scheduled_messages`, plus a content-safety line to the Girlfriend persona's system prompt.

I added handlers for `ForbiddenException` and `DailyLimitExceededException` to `GlobalExceptionHandler` so they return proper responses.

---

## What I couldn't verify

The environment I was working in doesn't have access to Maven Central, so I couldn't actually run `mvn compile` against the real dependency tree (Spring, Lombok, jjwt, firebase-admin). I checked every file by hand for import correctness and consistency with the rest of the codebase, but you should definitely run `./mvnw clean compile` yourself before trusting this is 100% green. If something breaks, let me know and I'll fix it.

---

## What's still not done

I didn't add any test files in this pass. Happy to add them if you want.

The `firebase-admin` SDK needs a real service-account JSON to actually send pushes. Without one, it degrades gracefully (logs only) – that's intentional, not a bug.

`test.html` and `body.json` (your manual test scratch files) are unchanged.

---

## Round 2 – after running it through IntelliJ

After the initial fixes, I ran everything through IntelliJ and caught a few more things.

I fixed `application.yml`'s Groq config. The `groq.api-key` had been hardcoded to the literal string `"my-api-key"`, completely ignoring `$GROQ_API_KEY`. Every chat request would've failed Groq's auth check no matter what you set in the shell. I reverted it to `${GROQ_API_KEY:your-groq-key}`. I also swapped `groq.model` off `llama-3.1-8b-instant`, which Groq announced as deprecated on 2026-06-17 (could already be unstable or gone), to `openai/gpt-oss-120b`, their current recommended replacement.

I restored the missing XML declaration (`<?xml version="1.0" encoding="UTF-8"?>`) at the top of `pom.xml` – not guaranteed to break a build on its own, but non-standard to omit.

I reviewed the rest of what changed in that IntelliJ pass and left it as-is. The changes were good: removing the explicit `hibernate.dialect` (Hibernate 6+ auto-detects it), adding `.requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()` plus `setMaxAge(3600L)` in `SecurityConfig` for CORS preflight, and the new `POST /api/chat/sync` endpoint for easier testing without dealing with SSE.

One small note: the comment added on `enforceDailyMessageLimit`'s new `@Transactional` says it's needed because `userRepository.save()` might not flush without it – that's not quite right (Spring Data's `save()` is already self-transactional), but the annotation itself is harmless either way.


## Round 3 – dependency vulnerability scan (Mend.io)
- **I upgraded `spring-boot-starter-parent` from `3.4.2` to `4.1.0`.** 3.4.2 reached open-source end-of-life on 2025-12-31 -- that's the direct reason every transitive dependency in the scan (Spring Framework 6.2.2, Spring Security 6.4.2, Tomcat 10.1.34, Netty 4.1.117.Final, logback 1.5.16) was carrying unpatched CVEs: no more patches get backported to an EOL line. 4.1.0 is the current actively-supported release and pulls in fixed versions of nearly everything the scan flagged. I considered 3.5.16 (smaller diff, still Spring Framework 6.x) as a lower-risk alternative, but Spring Boot 3.5 itself reaches end-of-life on 2026-06-30 -- one day from now as I write this -- so it would've been a very short-lived fix.
- **I pinned `org.postgresql:postgresql` to `42.7.7` explicitly.** CVE-2025-49146 affects 42.7.4 through 42.7.6 (a MITM bypass of `channelBinding=require`); 42.7.7 fixes it. I pinned it directly rather than relying on whatever version Boot 4.1.0's BOM happens to manage, so this specific CVE is resolved regardless.
- **I did not hand-pin the rest** (Jackson, Netty, Tomcat, Spring Security, httpclient5, json-smart, assertj) -- those all come transitively through `spring-boot-starter-parent`'s dependency management, and the 4.1.0 upgrade should carry all of them to patched versions on its own. Don't override them individually unless a `mvn dependency:tree` after this upgrade still shows an old version somewhere.

## What I could NOT verify about this round specifically
A Spring Boot 3.4 → 4.1 jump crosses a major Spring Framework version (6 → 7). The APIs this project actually uses (`SecurityFilterChain`, `HttpSecurity`, `OncePerRequestFilter`, `CorsConfigurationSource`, `BCryptPasswordEncoder`) have been stable across Spring Security major versions for years, so I expect this to compile cleanly, but I have no way to confirm that here -- same Maven Central access limitation as before. Run `.\mvnw.cmd clean compile` and send me the output. If it breaks in a way that's annoying to chase down before a deadline, tell me and I'll drop the parent version to `3.5.16` instead -- smaller jump, resolves most of the same CVEs, just shorter-lived support.