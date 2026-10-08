package com.innercircle.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.MDC;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.UUID;

/**
 * Assigns a correlation ID to every request and exposes it in:
 * - MDC (so structured logs carry it automatically)
 * - the X-Request-Id response header (so clients and load balancers can
 *   correlate a user-reported error with a specific server log line)
 *
 * Accepts an inbound X-Request-Id if a proxy or client already set one,
 * so distributed traces can be stitched together across services.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 1)
public class CorrelationIdFilter extends OncePerRequestFilter {

    public static final String MDC_KEY = "requestId";
    private static final String HEADER = "X-Request-Id";

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain chain)
            throws ServletException, IOException {

        String incoming = request.getHeader(HEADER);
        // Accept a caller-supplied ID only if it's a safe shape (UUID or
        // short alphanumeric) to prevent log injection via crafted headers.
        String requestId = (incoming != null && incoming.matches("[a-zA-Z0-9\\-]{8,64}"))
                ? incoming
                : UUID.randomUUID().toString();

        MDC.put(MDC_KEY, requestId);
        response.setHeader(HEADER, requestId);
        try {
            chain.doFilter(request, response);
        } finally {
            MDC.remove(MDC_KEY);
        }
    }
}
