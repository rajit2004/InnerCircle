package com.innercircle.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.nio.file.Paths;

@Configuration
public class WebMvcConfig implements WebMvcConfigurer {

    private static final String AVATAR_UPLOAD_DIR = "uploads/avatars/";

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        String absolutePath = Paths.get(AVATAR_UPLOAD_DIR).toAbsolutePath().toUri().toString();
        registry.addResourceHandler("/uploads/avatars/**")
                .addResourceLocations(absolutePath);
    }
}
