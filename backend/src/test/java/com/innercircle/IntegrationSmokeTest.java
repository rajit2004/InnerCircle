package com.innercircle;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.web.client.RestClient;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import com.innercircle.service.EmbeddingService;
import com.innercircle.service.ConversationUnderstandingService;
import com.innercircle.service.ConversationUnderstandingService.ConversationState;

import java.util.Map;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Boots the full app against a real (Testcontainers) pgvector Postgres and
 * exercises the critical auth + memory + chat paths over HTTP. This is the
 * runtime verification CI was missing: it proves the beans actually wire up,
 * the schema applies, JWT auth works, and -- most importantly -- that the
 * memory DTO change actually stops the password hash / reset token from
 * leaking out of the API.
 *
 * Notes on the Spring Boot 4 test surface used here:
 *  - TestRestTemplate / WebTestClient / @MockBean were removed in this
 *    generation, so we talk to the server with the modern RestClient and
 *    replace the Groq-calling EmbeddingService with a local stub bean
 *    (@Primary) so memory creation needs no network.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
@Import(IntegrationSmokeTest.StubConfig.class)
class IntegrationSmokeTest {

    @Container
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("pgvector/pgvector:pg16");

    @LocalServerPort
    int port;

    RestClient client;

    @DynamicPropertySource
    static void props(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
        registry.add("spring.sql.init.mode", () -> "always");
        registry.add("spring.sql.init.schema-locations", () -> "file:../database/schema.sql");
        registry.add("jwt.secret", () -> "test-secret-test-secret-test-secret-1234567890");
        registry.add("jwt.require-secret", () -> "false");
        registry.add("groq.api-key", () -> "test-key");
        registry.add("groq.url", () -> "http://localhost:0/chat/completions");
        registry.add("groq.model", () -> "test-model");
    }

    @BeforeEach
    void init() {
        client = RestClient.builder().baseUrl("http://localhost:" + port).build();
    }

    private static String extractToken(String json) {
        Matcher m = Pattern.compile("\"token\"\\s*:\\s*\"([^\"]+)\"").matcher(json);
        if (m.find()) return m.group(1);
        throw new IllegalStateException("token not found in: " + json);
    }

    @Test
    void registerLoginAndMemoryDoesNotLeakPassword() {
        String email = "smoke-" + UUID.randomUUID() + "@example.com";
        String password = "Password123!";

        ResponseEntity<String> registered = client.post().uri("/api/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .body(Map.of("email", email, "password", password))
                .retrieve().toEntity(String.class);
        assertThat(registered.getStatusCode()).isEqualTo(HttpStatus.OK);
        String token = extractToken(registered.getBody());
        assertThat(token).isNotBlank();

        assertThat(client.post().uri("/api/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .body(Map.of("email", email, "password", password))
                .retrieve().toEntity(String.class).getStatusCode()).isEqualTo(HttpStatus.OK);

        String auth = "Bearer " + token;

        assertThat(client.get().uri("/api/personas")
                .header("Authorization", auth)
                .retrieve().toEntity(String.class).getStatusCode()).isEqualTo(HttpStatus.OK);

        UUID mom = UUID.fromString("550e8400-e29b-41d4-a716-446655440000");
        ResponseEntity<String> created = client.post().uri("/api/memories")
                .header("Authorization", auth)
                .contentType(MediaType.APPLICATION_JSON)
                .body(Map.of("fact", "User loves hamburgers",
                        "personaId", mom.toString(), "shared", true))
                .retrieve().toEntity(String.class);
        assertThat(created.getStatusCode()).isEqualTo(HttpStatus.OK);
        String body = created.getBody();
        assertThat(body).doesNotContain("passwordHash");
        assertThat(body).doesNotContain("resetToken");
        assertThat(body).contains("User loves hamburgers");
        assertThat(body).contains("\"shared\":true");

        ResponseEntity<String> listed = client.get().uri("/api/memories")
                .header("Authorization", auth)
                .retrieve().toEntity(String.class);
        assertThat(listed.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(listed.getBody()).doesNotContain("passwordHash");
        assertThat(listed.getBody()).doesNotContain("resetToken");

        assertThat(client.get().uri("/api/chat/history?personaId=" + mom)
                .header("Authorization", auth)
                .retrieve().toEntity(String.class).getStatusCode()).isEqualTo(HttpStatus.OK);

        assertThat(client.delete().uri("/api/chat?personaId=" + mom)
                .header("Authorization", auth)
                .retrieve().toBodilessEntity().getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
    }

    @TestConfiguration
    static class StubConfig {
        @Bean
        @Primary
        EmbeddingService embeddingService() {
            return new EmbeddingService() {
                @Override
                public float[] embed(String text) {
                    return new float[1536];
                }

                @Override
                public String toPgVectorLiteral(float[] e) {
                    StringBuilder sb = new StringBuilder("[");
                    for (int i = 0; i < e.length; i++) {
                        sb.append(e[i]);
                        if (i < e.length - 1) sb.append(",");
                    }
                    return sb.append("]").toString();
                }
            };
        }

        @Bean
        @Primary
        ConversationUnderstandingService conversationUnderstandingService() {
            return new ConversationUnderstandingService(null) {
                @Override
                public ConversationState analyze(String userMessage, java.util.List<java.util.Map<String, String>> recentMessages) {
                    return ConversationState.builder()
                            .intent("REACTION")
                            .emotion("neutral")
                            .emotionalIntensity("low")
                            .topic("")
                            .needsResponse(true)
                            .isQuestion(false)
                            .isShortForm(userMessage.trim().length() <= 5)
                            .responseLengthHint("short")
                            .requiresEmotionalResponse(false)
                            .shouldAskFollowup(false)
                            .userEnergy("medium")
                            .build();
                }
            };
        }
    }
}
