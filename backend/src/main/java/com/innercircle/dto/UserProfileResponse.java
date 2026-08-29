package com.innercircle.dto;

import lombok.AllArgsConstructor;
import lombok.Data;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Data
@AllArgsConstructor
public class UserProfileResponse {
    private UUID id;
    private String email;
    private String displayName;
    private String avatarUrl;
    private String subscriptionTier;
    private int messagesUsedToday;
    private int dailyMessageLimit;
    private LocalDate lastMessageDate;
    private LocalDate dateOfBirth;
    private String language;
    private String timezone;
    private Instant memberSince;
}
