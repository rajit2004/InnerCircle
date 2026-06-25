package com.innercircle.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

// BUG FIX: CorsConfig was using @Value("${cors.allowed-origins}") and registering
// its own addCorsMappings(), which duplicates and conflicts with the
// corsConfigurationSource() bean in SecurityConfig. When both are active,
// Spring Security's CORS filter and MVC's CORS interceptor both fire on the same
// request, which can result in double Access-Control-Allow-Origin headers (rejected
// by browsers) or inconsistent pre-flight handling.
// Fix: removed addCorsMappings() entirely. All CORS is handled in SecurityConfig.
@Configuration
public class CorsConfig implements WebMvcConfigurer {
    // Intentionally empty — CORS is fully handled by SecurityConfig.corsConfigurationSource()
}
