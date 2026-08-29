package com.innercircle.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.Instant;

@Entity
@Table(name = "user_preferences")
@Data
@NoArgsConstructor
public class UserPreferences {

    @Id
    @Column(name = "user_id")
    private java.util.UUID userId;

    @OneToOne
    @MapsId
    @JoinColumn(name = "user_id")
    private User user;

    private String preferredName;
    private String communicationStyle = "casual";
    private String responseLength = "moderate";

    @Column(columnDefinition = "TEXT DEFAULT '[]'")
    private String interests = "[]";

    @Column(columnDefinition = "TEXT DEFAULT '[]'")
    private String goals = "[]";

    private boolean memoryEnabled = true;

    @CreationTimestamp
    private Instant createdAt;

    @UpdateTimestamp
    private Instant updatedAt;
}
