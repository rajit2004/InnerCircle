package com.innercircle.repository;

import com.innercircle.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;

public interface UserRepository extends JpaRepository<User, UUID> {
    Optional<User> findByEmail(String email);
    boolean existsByEmail(String email);

    // FEATURE (forgot password, 2026-07-06): looks up whichever user currently
    // holds this reset token. See AuthService.resetPassword().
    Optional<User> findByResetToken(String token);

    /**
     * SECURITY: atomic daily-quota increment. The previous check-then-save
     * in ChatService.enforceDailyMessageLimit raced under concurrent
     * requests (two threads both read messagesUsedToday=49, both wrote 50).
     * This single UPDATE enforces the limit and increments in one step;
     * returns 0 rows when the user is already at the limit.
     */
    @Modifying
    @Query(value = """
            UPDATE profiles
               SET messages_used_today = messages_used_today + 1,
                   last_message_date = :today,
                   updated_at = NOW()
             WHERE id = :id
               AND (last_message_date IS DISTINCT FROM :today OR messages_used_today < :limit)
            """, nativeQuery = true)
    int tryIncrementDailyQuota(@Param("id") UUID id,
                               @Param("today") LocalDate today,
                               @Param("limit") int limit);

    @Modifying
    @Query(value = """
            UPDATE profiles
               SET messages_used_today = 1,
                   last_message_date = :today,
                   updated_at = NOW()
             WHERE id = :id
               AND last_message_date IS DISTINCT FROM :today
            """, nativeQuery = true)
    int resetDailyQuotaForNewDay(@Param("id") UUID id, @Param("today") LocalDate today);
}