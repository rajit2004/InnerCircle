package com.innercircle.service;

import com.innercircle.model.User;
import lombok.RequiredArgsConstructor;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.util.Map;

@Service
@RequiredArgsConstructor
public class NotificationService {

    // In production, inject FCM and repository for scheduled_messages

    public void registerToken(User user, String token, String platform) {
        // Save to push_tokens table
        System.out.println("Registered token for user: " + user.getId() + ", token: " + token + ", platform: " + platform);
    }

    public void scheduleMessage(User user, String personaId, String scheduledAt, String daysOfWeek, String messageType) {
        // Save to scheduled_messages table
        System.out.println("Scheduled message for user: " + user.getId() + ", persona: " + personaId + ", at: " + scheduledAt);
    }

    @Scheduled(cron = "0 * * * * *") // Every minute
    public void checkScheduledMessages() {
        // Query scheduled_messages table and send FCM pushes
        System.out.println("Checking scheduled messages...");
        // Implement later
    }
}