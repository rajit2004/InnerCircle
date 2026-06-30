package com.innercircle.service;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.io.FileInputStream;
import java.io.IOException;

/**
 * Initializes Firebase Admin SDK if firebase.credentials-path is configured
 * and points to a real service-account JSON file. If not configured, the app
 * still starts fine -- NotificationService.sendPush() just logs instead of
 * sending, rather than crashing on a missing credential at startup.
 */
@Component
@Slf4j
public class FirebaseInitializer {

    private static volatile boolean initialized = false;

    @Value("${firebase.credentials-path:}")
    private String credentialsPath;

    @PostConstruct
    public void init() {
        if (credentialsPath == null || credentialsPath.isBlank()) {
            log.warn("firebase.credentials-path not set -- push notifications will be logged, not sent. " +
                    "Set FCM_CREDENTIALS_PATH to a Firebase service-account JSON to enable real delivery.");
            return;
        }

        try (FileInputStream serviceAccount = new FileInputStream(credentialsPath)) {
            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                    .build();

            if (FirebaseApp.getApps().isEmpty()) {
                FirebaseApp.initializeApp(options);
            }
            initialized = true;
            log.info("Firebase initialized from {}", credentialsPath);
        } catch (IOException e) {
            log.error("Failed to initialize Firebase from {}: {}", credentialsPath, e.getMessage());
        }
    }

    public static boolean isInitialized() {
        return initialized;
    }
}
