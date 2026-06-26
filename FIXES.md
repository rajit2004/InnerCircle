# Fixes applied

## Critical security
- **I reverted the auth bypass.** `SecurityConfig` had been set to `anyRequest().permitAll()` with `JwtAuthFilter` never registered – I restored real JWT enforcement and kept the `CorsConfigurationSource` bean.
- **I removed the dev bypass from `JwtAuthFilter`.** It was injecting a hardcoded fake user (`ranesha@example.com`) for every request to `/api/chat`, no token required – now it's gone.
- **I kept/verified IDOR fixes:** I made sure conversation‑continuation ownership checks are in place, fixed memory mass‑assignment, and enforced ownership checks on memory deletion.

## Build
- `pom.xml`: I reverted `modelVersion`/`xmlns` from `4.1.0` back to standard `4.0.0` – nothing in this POM uses a Maven‑4‑only feature, and plain `mvn` (Maven 3.x) would reject `4.1.0`.
- `.mvn/wrapper/maven-wrapper.properties`: I pointed it back to a stable Maven 3.9.9 release instead of an RC build of Maven 4.

## Exceptions / status codes
- In `AuthService.register()`, I changed the raw `RuntimeException` to throw `DuplicateEmailException` – that way the existing 409 handler actually fires.
- In `ChatService`, I made tier‑gating and conversation‑ownership checks throw `ForbiddenException` (403) instead of `UnauthorizedException` (401) – these are permission issues, not login failures, and a 401 would risk the client force‑logging the user out.
- I added `DailyLimitExceededException` (429) to support the new daily message cap.

## Memory / pgvector
- I added `EmbeddingService` – a dependency‑free feature‑hashing embedding (1536‑dim, L2‑normalised). It's not a real semantic model (Groq doesn't offer embeddings), but it's a genuine, working vector that pgvector can actually search on (instead of an unused column).
- In `MemoryRepository.findRelevantMemories()`, I implemented a real native `<=>` cosine‑distance query.
- I updated `MemoryService`/`ChatService` to retrieve memories relevant to the *current message*, not just "top 3 most important ever." It falls back to importance‑ranking if no embedded memories exist yet.
- `MemoryService.extractAndStoreMemory()` now stores an embedding for every extracted fact.

## Notifications
- I added `PushToken` and `ScheduledMessage` entities + repositories – previously they didn't exist, so `NotificationController` was accepting data and discarding it.
- `NotificationService` now actually persists tokens/schedules, and the `@Scheduled` job reads real rows and sends real pushes via **FCM's current v1 API** (the legacy `fcm.googleapis.com/fcm/send` + server‑key endpoint from older tutorials was shut down by Google in mid‑2024 – using it would fail outright).
- If no Firebase service‑account JSON is configured (`FCM_CREDENTIALS_PATH`), it logs instead of pretending to send. Set that env var to a real service‑account file to enable delivery.
- I split the bloated `NotificationRequest` DTO into `NotificationRegisterRequest` and `NotificationScheduleRequest` – the old shared DTO made `/schedule` require an irrelevant `token`/`platform`, and had no `@NotNull` on `scheduledAt` (NPE risk).

## Other
- I enforced the daily free‑tier cap (50 msgs/day) – now it actually checks `User.lastMessageDate` and `messagesUsedToday`, with reset‑on‑new‑day logic.
- In `schema.sql`, I restored Girlfriend/Big Sister to `premium` tier (they were all `free`, making the tier‑gating code never trigger). I added `last_message_date`, `push_tokens`, and `scheduled_messages`. I also added a content‑safety line to the Girlfriend persona's system prompt.
- I added handlers for `ForbiddenException` and `DailyLimitExceededException` to `GlobalExceptionHandler`.

## What I could NOT verify here
This sandbox has no access to Maven Central, so I couldn't run `mvn compile` against the real dependency tree (Spring, Lombok, jjwt, firebase‑admin). I checked every file by hand for import correctness and consistency with the rest of the codebase, but **you should run `./mvnw clean compile` yourself before trusting this is 100% green** – and tell me what breaks, so I can fix it directly.

## What's still NOT done (I didn't try to fix – flagging instead)
- Zero test files. I didn't add any in this pass – happy to if you want.
- `firebase‑admin` SDK requires a real service‑account JSON to actually send pushes; without one it degrades gracefully (logs only) – that's intentional, not a bug.
- `test.html` / `body.json` (your manual test scratch files) are unchanged.