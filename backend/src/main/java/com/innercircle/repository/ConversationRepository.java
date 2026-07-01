package com.innercircle.repository;

import com.innercircle.model.Conversation;
import com.innercircle.model.Persona;
import com.innercircle.model.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ConversationRepository extends JpaRepository<Conversation, UUID> {
    List<Conversation> findByUserOrderByUpdatedAtDesc(User user);

    // FEATURE (chat history, 2026-07-02): needed to resume the most recent
    // conversation for a given user+persona pair. See ChatService.getHistory()
    // and bugs.md for the full story on why this was missing -- the frontend
    // had nowhere to fetch past messages from, so every screen reopen started
    // a brand new conversation with zero memory of what was said before,
    // including any in-chat style instructions like "reply shorter".
    Optional<Conversation> findFirstByUserAndPersonaOrderByUpdatedAtDesc(User user, Persona persona);
}