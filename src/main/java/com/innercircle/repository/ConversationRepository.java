package com.innercircle.repository;

import com.innercircle.model.Conversation;
import com.innercircle.model.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface ConversationRepository extends JpaRepository<Conversation, UUID> {
    List<Conversation> findByUserOrderByUpdatedAtDesc(User user);
}