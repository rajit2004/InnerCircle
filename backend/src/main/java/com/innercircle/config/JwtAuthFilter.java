package src.main.java.com.innercircle.config;

import com.innercircle.model.User;
import com.innercircle.repository.UserRepository;
import com.innercircle.util.JwtUtil;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;
import java.util.UUID;

// FIX: removed the hardcoded "/api/chat development bypass" that injected a
// fake User (ranesha@example.com, hardcoded UUID) for every request to that
// path regardless of whether a real token was presented. That bypass was
// already committed to origin/main. This filter now does real JWT validation
// for every request, with no path-based exception.
@Component
@RequiredArgsConstructor
@Slf4j
public class JwtAuthFilter extends OncePerRequestFilter {

    private final JwtUtil jwtUtil;
    private final UserRepository userRepository;

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {

        String authHeader = request.getHeader("Authorization");

        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7);

            try {
                if (!jwtUtil.validateToken(token)) {
                    throw new IllegalArgumentException("Invalid or expired token");
                }

                UUID userId = UUID.fromString(jwtUtil.extractUserId(token));
                String role = jwtUtil.extractRole(token);

                // Load the real User entity so @AuthenticationPrincipal User user
                // resolves correctly downstream -- a bare String/UUID principal
                // would silently inject null wherever a User is expected.
                User user = userRepository.findById(userId)
                        .orElseThrow(() -> new IllegalArgumentException("Token references a user that no longer exists"));

                List<SimpleGrantedAuthority> authorities = List.of(
                        new SimpleGrantedAuthority("ROLE_" + (role != null ? role : "USER"))
                );

                UsernamePasswordAuthenticationToken auth =
                        new UsernamePasswordAuthenticationToken(user, null, authorities);
                SecurityContextHolder.getContext().setAuthentication(auth);

            } catch (Exception e) {
                // Invalid/expired token, or user no longer exists -- leave the
                // request unauthenticated. SecurityConfig rejects it downstream
                // with 401/403 rather than this filter doing it directly.
                SecurityContextHolder.clearContext();
                log.debug("JWT validation failed: {}", e.getMessage());
            }
        }

        filterChain.doFilter(request, response);
    }
}
