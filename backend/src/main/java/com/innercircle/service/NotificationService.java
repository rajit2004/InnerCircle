package com.innercircle.service;

import com.innercircle.dto.ScheduledMessageResponse;
import com.innercircle.exception.ForbiddenException;
import com.innercircle.exception.ResourceNotFoundException;
import com.innercircle.model.*;
import com.innercircle.repository.PersonaRepository;
import com.innercircle.repository.PushTokenRepository;
import com.innercircle.repository.ScheduledMessageRepository;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class NotificationService {

    private final PushTokenRepository pushTokenRepository;
    private final ScheduledMessageRepository scheduledMessageRepository;
    private final PersonaRepository personaRepository;

    public void registerToken(User user, String token, String platform) {
        PushToken pushToken = pushTokenRepository.findByUserAndPlatform(user, platform)
                .orElseGet(PushToken::new);
        pushToken.setUser(user);
        pushToken.setToken(token);
        pushToken.setPlatform(platform);
        pushTokenRepository.save(pushToken);
        log.info("Registered {} push token for user {}", platform, user.getId());
    }

    public ScheduledMessage scheduleMessage(User user, UUID personaId, LocalTime scheduledAt,
                                            String daysOfWeek, String messageType) {
        Persona persona = personaRepository.findById(personaId)
                .orElseThrow(() -> new ResourceNotFoundException("Persona not found"));

        ScheduledMessage scheduled = new ScheduledMessage();
        scheduled.setUser(user);
        scheduled.setPersona(persona);
        scheduled.setScheduledAt(scheduledAt);
        scheduled.setDaysOfWeek(daysOfWeek != null ? daysOfWeek : "1,2,3,4,5,6,7");
        scheduled.setMessageType(messageType != null ? messageType : "check_in");
        return scheduledMessageRepository.save(scheduled);
    }

    // FEATURE (notification management, 2026-07-04): previously there was no
    // way to see what check-ins were even scheduled, cancel one, or pause it
    // without deleting it outright -- POST /schedule was write-only. These
    // three methods back the new GET/DELETE/toggle endpoints on
    // NotificationController.

    public List<ScheduledMessageResponse> listForUser(User user) {
        return scheduledMessageRepository.findByUserOrderByScheduledAtAsc(user).stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional
    public void cancel(UUID scheduledMessageId, User user) {
        ScheduledMessage scheduled = findOwned(scheduledMessageId, user);
        scheduledMessageRepository.delete(scheduled);
    }

    @Transactional
    public ScheduledMessageResponse setActive(UUID scheduledMessageId, User user, boolean active) {
        ScheduledMessage scheduled = findOwned(scheduledMessageId, user);
        scheduled.setActive(active);
        return toResponse(scheduledMessageRepository.save(scheduled));
    }

    private ScheduledMessage findOwned(UUID scheduledMessageId, User user) {
        ScheduledMessage scheduled = scheduledMessageRepository.findById(scheduledMessageId)
                .orElseThrow(() -> new ResourceNotFoundException("Scheduled check-in not found"));
        if (!scheduled.getUser().getId().equals(user.getId())) {
            throw new ForbiddenException("You do not have permission to modify this scheduled check-in");
        }
        return scheduled;
    }

    private ScheduledMessageResponse toResponse(ScheduledMessage sm) {
        return new ScheduledMessageResponse(
                sm.getId(),
                sm.getPersona().getId(),
                sm.getPersona().getName(),
                sm.getPersona().getAvatarEmoji(),
                sm.getScheduledAt(),
                sm.getDaysOfWeek(),
                sm.getMessageType(),
                sm.isActive(),
                sm.getLastSentAt()
        );
    }

    /**
     * Runs every minute, checks for scheduled check-ins due "now" (matched to
     * the current minute, on a day this schedule applies to), and sends a
     * push for each one that hasn't already fired in the last hour.
     */
    @Scheduled(cron = "0 * * * * *")
    public void checkScheduledMessages() {
        LocalDateTime now = LocalDateTime.now();
        LocalTime currentMinute = now.toLocalTime().withSecond(0).withNano(0);
        // Java DayOfWeek is 1=Monday..7=Sunday; this schema's days_of_week uses
        // 1=Sunday..7=Saturday, so convert. NOTE: this is an internal convention
        // (NOT Postgres EXTRACT(DOW), which is 0=Sunday..6=Saturday) -- the DB
        // column just stores the CSV string "1,2,...".
        int isoDay = now.getDayOfWeek().getValue(); // 1=Mon .. 7=Sun
        int dowSundayBased = (isoDay % 7) + 1;       // 1=Sun .. 7=Sat

        List<ScheduledMessage> due = scheduledMessageRepository.findByActiveTrue().stream()
                .filter(sm -> sm.getScheduledAt().withSecond(0).withNano(0).equals(currentMinute))
                .filter(sm -> dayMatches(sm.getDaysOfWeek(), dowSundayBased))
                .filter(sm -> sm.getLastSentAt() == null
                        || sm.getLastSentAt().isBefore(Instant.now().minus(1, ChronoUnit.HOURS)))
                .toList();

        for (ScheduledMessage sm : due) {
            try {
                sendCheckIn(sm);
                sm.setLastSentAt(Instant.now());
                scheduledMessageRepository.save(sm);
            } catch (Exception e) {
                log.error("Failed to send scheduled check-in {}: {}", sm.getId(), e.getMessage());
            }
        }
    }

    private void sendCheckIn(ScheduledMessage sm) {
        User user = sm.getUser();
        Persona persona = sm.getPersona();
        String title = persona.getName();
        String body = persona.getGreeting() != null ? persona.getGreeting() : "Checking in on you \uD83D\uDCAD";

        List<PushToken> tokens = pushTokenRepository.findByUser(user);
        if (tokens.isEmpty()) {
            log.debug("No push tokens for user {}, skipping check-in send", user.getId());
            return;
        }
        for (PushToken token : tokens) {
            sendPush(token, title, body);
        }
    }

    /**
     * Sends via Firebase Cloud Messaging HTTP v1 API (FirebaseMessaging Admin SDK).
     *
     * NOTE: the old FCM legacy HTTP API (fcm.googleapis.com/fcm/send + a bare
     * server key) was shut down by Google in June 2024 -- code calling that
     * endpoint will fail outright. This uses the current v1 API via the
     * official SDK instead. It requires a Firebase service-account JSON file;
     * see application.yml `firebase.credentials-path`. If that's not
     * configured, this logs instead of pretending to have sent something.
     */
    private void sendPush(PushToken pushToken, String title, String body) {
        if (!FirebaseInitializer.isInitialized()) {
            log.info("[FCM not configured] Would send to user {} ({}): {} - {}",
                    pushToken.getUser().getId(), pushToken.getPlatform(), title, body);
            return;
        }

        Message message = Message.builder()
                .setToken(pushToken.getToken())
                .setNotification(Notification.builder().setTitle(title).setBody(body).build())
                .build();

        try {
            String response = FirebaseMessaging.getInstance().send(message);
            log.info("FCM push sent: {}", response);
        } catch (FirebaseMessagingException e) {
            log.error("FCM push failed for token {}...: {}", safePrefix(pushToken.getToken()), e.getMessage());
        }
    }

    private String safePrefix(String token) {
        return token == null ? "null" : token.substring(0, Math.min(8, token.length()));
    }

    // BUG FIX: previously used daysOfWeek.contains(String.valueOf(day)), which
    // is a substring test -- e.g. "12" would falsely match day 1 or 2. Match by
    // exact CSV token instead.
    private boolean dayMatches(String daysOfWeek, int day) {
        if (daysOfWeek == null || daysOfWeek.isBlank()) return true; // no restriction = every day
        for (String part : daysOfWeek.split(",")) {
            String trimmed = part.trim();
            if (trimmed.isEmpty()) continue;
            try {
                if (Integer.parseInt(trimmed) == day) return true;
            } catch (NumberFormatException ignored) {
                // ignore malformed tokens
            }
        }
        return false;
    }
}