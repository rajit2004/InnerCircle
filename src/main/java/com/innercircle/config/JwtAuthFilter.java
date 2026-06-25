package com.innercircle.config;

import com.innercircle.model.SubscriptionTier;
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

        // ---------- DEVELOPMENT BYPASS FOR /api/chat ----------
        if (request.getRequestURI().startsWith("/api/chat")) {
            // Create a dummy User object
            User dummyUser = new User();
            dummyUser.setId(UUID.fromString("1ccb14cc-f8cd-48f7-a9a9-3de93c5dd94e"));
            dummyUser.setEmail("ranesha@example.com");

            // Try to set subscriptionTier – if this setter doesn't exist, comment it out
            // and manually set the tier via reflection or a constructor later.
            try {
                dummyUser.setSubscriptionTier(SubscriptionTier.free);
            } catch (NoSuchMethodError e) {
                // If setSubscriptionTier doesn't exist, we'll log a warning.
                log.warn("User.setSubscriptionTier() not found – using default. You may need to add it.");
                // You can also use a different approach: create a User via a constructor that includes tier.
            }

            // We do NOT call setRole() – the role is set in the authorities list below.

            UsernamePasswordAuthenticationToken auth =
                    new UsernamePasswordAuthenticationToken(
                            dummyUser,                            // principal
                            null,
                            List.of(new SimpleGrantedAuthority("ROLE_USER"))
                    );

            SecurityContextHolder.getContext().setAuthentication(auth);
            log.info("🔓 Bypassed authentication for /api/chat – using dummy user: {}", dummyUser.getEmail());

            filterChain.doFilter(request, response);
            return;
        }
        // ---------- END OF BYPASS ----------

        // ---------- ORIGINAL JWT VALIDATION ----------
        String authHeader = request.getHeader("Authorization");

        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7);

            try {
                if (!jwtUtil.validateToken(token)) {
                    throw new RuntimeException("Invalid token");
                }

                String userId = jwtUtil.extractUserId(token);
                String email = jwtUtil.extractEmail(token);
                String role = jwtUtil.extractRole(token);

                User user = userRepository.findById(UUID.fromString(userId))
                        .orElseThrow(() -> new RuntimeException("User not found"));

                List<SimpleGrantedAuthority> authorities = List.of(
                        new SimpleGrantedAuthority("ROLE_" + (role != null ? role : "USER"))
                );

                UsernamePasswordAuthenticationToken auth =
                        new UsernamePasswordAuthenticationToken(user, null, authorities);
                SecurityContextHolder.getContext().setAuthentication(auth);

            } catch (Exception e) {
                log.warn("JWT validation failed: {}", e.getMessage());
            }
        }

        filterChain.doFilter(request, response);
    }
}