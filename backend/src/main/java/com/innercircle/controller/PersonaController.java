package src.main.java.com.innercircle.controller;

import com.innercircle.model.Persona;
import com.innercircle.model.User;
import com.innercircle.service.PersonaService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/personas")
@RequiredArgsConstructor
public class PersonaController {

    private final PersonaService personaService;

    @GetMapping
    public List<Persona> getPersonas(@AuthenticationPrincipal User user) {
        return personaService.getPersonasForUser(user);
    }
}