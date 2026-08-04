package com.innercircle.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "messages")
@Data
@NoArgsConstructor
public class Message {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne
    @JoinColumn(name = "conversation_id", nullable = false)
    private Conversation conversation;

    @Column(nullable = false)
    private String role; // 'user', 'assistant', 'system'

    @Column(columnDefinition = "TEXT", nullable = false)
    private String content;

    private int tokensUsed = 0;

    // FEATURE (message reactions, round 12): a single emoji, or null for no
    // reaction. One per message -- this is a 1:1 conversation, not a group
    // chat, so there's no need to support multiple people reacting
    // differently to the same message.
    private String reaction;

    @CreationTimestamp
    private Instant createdAt;
}