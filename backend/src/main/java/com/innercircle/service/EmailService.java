package com.innercircle.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

/**
 * FEATURE (forgot password, 2026-07-06): sends the password reset code by
 * email when SMTP is configured. Same honest-fallback pattern already used
 * for Firebase in FirebaseInitializer/NotificationService: if
 * spring.mail.host isn't set (see application.yml), Spring Boot never even
 * creates a JavaMailSender bean at all -- rather than crash on startup or
 * throw at request time, this uses ObjectProvider to treat that bean as
 * genuinely optional, and logs the reset code instead of pretending to have
 * emailed something it didn't. For local development, that means the
 * person requesting a reset just reads the code from their own backend
 * console -- they control that server, so this isn't a security gap, it's
 * the same "not configured -> log instead" honesty applied consistently.
 *
 * Real email delivery needs actual SMTP credentials (a Gmail app password,
 * SendGrid, Mailgun, etc.) configured via the spring.mail.* properties --
 * see application.yml's comments and PUSH_NOTIFICATIONS_SETUP.md-style
 * setup notes for the equivalent walkthrough for email if you want this
 * to actually deliver to a real inbox.
 */
@Service
@Slf4j
public class EmailService {

    private final ObjectProvider<JavaMailSender> mailSenderProvider;
    private final String fromAddress;

    public EmailService(ObjectProvider<JavaMailSender> mailSenderProvider,
                        org.springframework.core.env.Environment env) {
        this.mailSenderProvider = mailSenderProvider;
        this.fromAddress = env.getProperty("spring.mail.username", "no-reply@innercircle.local");
    }

    public void sendPasswordResetEmail(String toEmail, String resetToken) {
        JavaMailSender mailSender = mailSenderProvider.getIfAvailable();

        if (mailSender == null) {
            log.warn("[Email not configured] Password reset requested for {} -- reset code: {}",
                    toEmail, resetToken);
            return;
        }

        try {
            SimpleMailMessage message = new SimpleMailMessage();
            message.setFrom(fromAddress);
            message.setTo(toEmail);
            message.setSubject("Your InnerCircle password reset code");
            message.setText(
                    "Someone (hopefully you) requested a password reset for your InnerCircle account.\n\n" +
                            "Your reset code is:\n\n" +
                            resetToken + "\n\n" +
                            "Enter this code in the app's \"Reset password\" screen. This code expires in 30 minutes.\n\n" +
                            "If you didn't request this, you can safely ignore this email."
            );
            mailSender.send(message);
            log.info("Password reset email sent to {}", toEmail);
        } catch (Exception e) {
            // Same principle as FCM push failures elsewhere in this app: log
            // and move on rather than surfacing an internal mail-server error
            // to the person who just wanted to reset their password.
            log.error("Failed to send password reset email to {}: {} -- reset code: {}",
                    toEmail, e.getMessage(), resetToken);
        }
    }
}