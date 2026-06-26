package com.innercircle.repository;

import com.innercircle.model.ScheduledMessage;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface ScheduledMessageRepository extends JpaRepository<ScheduledMessage, UUID> {
    List<ScheduledMessage> findByActiveTrue();
}
