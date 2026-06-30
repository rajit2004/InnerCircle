package src.main.java.com.innercircle.repository;

import com.innercircle.model.PushToken;
import com.innercircle.model.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface PushTokenRepository extends JpaRepository<PushToken, UUID> {
    List<PushToken> findByUser(User user);
    Optional<PushToken> findByUserAndPlatform(User user, String platform);
}
