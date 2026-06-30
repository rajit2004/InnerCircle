package src.main.java.com.innercircle.service;

import com.innercircle.exception.ResourceNotFoundException;
import com.innercircle.model.Persona;
import com.innercircle.model.SubscriptionTier;
import com.innercircle.model.User;
import com.innercircle.repository.PersonaRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class PersonaService {

    private final PersonaRepository personaRepository;

    public List<Persona> getPersonasForUser(User user) {
        List<SubscriptionTier> tiers = List.of(user.getSubscriptionTier(), SubscriptionTier.free);
        return personaRepository.findBySubscriptionTierIn(tiers);
    }

    public Persona getPersonaById(UUID id) {
        return personaRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Persona not found"));
    }

    public boolean isPersonaAccessible(User user, UUID personaId) {
        Persona persona = getPersonaById(personaId);
        return user.getSubscriptionTier() == SubscriptionTier.premium || persona.getSubscriptionTier() == SubscriptionTier.free;
    }
}