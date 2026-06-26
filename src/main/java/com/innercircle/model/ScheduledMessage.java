package com.innercircle.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;
import java.time.LocalTime;
import java.util.UUID;

@Entity
@Table(name = "scheduled_messages")
@Data
@NoArgsConstructor
public class ScheduledMessage {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne
    @JoinColumn(name = "persona_id", nullable = false)
    private Persona persona;

    @Column(nullable = false)
    private LocalTime scheduledAt;

    private String daysOfWeek = "1,2,3,4,5,6,7"; // 1=Sunday .. 7=Saturday

    private String messageType = "check_in";

    @Column(name = "is_active")
    private boolean active = true;

    private Instant lastSentAt;

    @CreationTimestamp
    private Instant createdAt;
}
