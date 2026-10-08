package com.innercircle.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/**
 * Adds security-relevant response headers to every HTTP response.
 *
 * Runs before the security filter chain so headers are set even on
 * 401/403 responses from the authorization layer.
 *
 * Note on CSP: the backend is a pure JSON API — it never serves HTML.
 * A strict CSP here mainly protects against content-type sniffing if a
 * misconfigured proxy ever serves an error page as text/html. The
 * Flutter web frontend has its own CSP meta tag in index.html.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class SecurityHeadersFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain chain)
            throws ServletException, IOException {

        // Prevent MIME-type sniffing — a response declared as an image
        // must never be re-interpreted as HTML/JS.
        response.setHeader("X-Content-Type-Options", "nosniff");

        // Disallow framing entirely (API responses are not embeddable).
        response.setHeader("X-Frame-Options", "DENY");

        // Referrer policy: no referrer leaves the API.
        response.setHeader("Referrer-Policy", "no-referrer");

        // Permissions-Policy: deny everything the API does not use.
        response.setHeader("Permissions-Policy",
                "camera=(), microphone=(), geolocation=(), payment=(), usb=()");

        // Strict-Transport-Security — only meaningful over HTTPS.
        // max-age=1yr, includeSubDomains, no preload (can be added later
        // once all subdomains are confirmed HTTPS-only).
        if (request.isSecure()) {
            response.setHeader("Strict-Transport-Security",
                    "max-age=31536000; includeSubDomains");
        }

        // Content-Security-Policy: default-src 'none' is correct for a
        // pure JSON API — nothing should ever be loaded by a browser
        // that receives these responses.
        response.setHeader("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'");

        // Cross-Origin policies (relevant if the API is ever opened to
        // third-party fetches).
        response.setHeader("Cross-Origin-Opener-Policy", "same-origin");
        response.setHeader("Cross-Origin-Resource-Policy", "same-site");

        // Cache policy: API responses are per-user — never cache them
        // in shared proxies. SSE/streaming endpoints override this.
        String path = request.getRequestURI();
        if (!path.startsWith("/actuator") && !path.startsWith("/api/auth/refresh")) {
            response.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, private");
            response.setHeader("Pragma", "no-cache");
        }

        chain.doFilter(request, response);
    }
}
