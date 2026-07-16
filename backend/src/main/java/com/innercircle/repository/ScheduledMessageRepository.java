package com.innercircle.repository;

import com.innercircle.model.ScheduledMessage;
import com.innercircle.model.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface ScheduledMessageRepository extends JpaRepository<ScheduledMessage, UUID> {
    List<ScheduledMessage> findByActiveTrue();

    // FEATURE (notification management, 2026-07-04): needed to list a user's
    // own scheduled check-ins. Ordered by time-of-day since that's the most
    // natural way to scan a list of "things that happen at X o'clock."
    List<ScheduledMessage> findByUserOrderByScheduledAtAsc(User user);
}