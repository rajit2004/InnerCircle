package com.innercircle.config;

import io.netty.channel.ChannelOption;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.reactive.ReactorClientHttpConnector;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.netty.http.client.HttpClient;

import java.time.Duration;

@Configuration
public class WebClientConfig {

    // SECURITY/RELIABILITY: default WebClient has NO connect/read timeout —
    // a hung Groq call would block a request thread (and, for chat, hold a
    // DB connection inside @Transactional) indefinitely. Connect fails fast
    // at 5s; read allows up to 15s which is comfortably under the 30s
    // per-call .timeout() ChatService already applies as a second layer.
    @Bean
    public WebClient webClient() {
        HttpClient httpClient = HttpClient.create()
                .option(ChannelOption.CONNECT_TIMEOUT_MILLIS, 5000)
                .responseTimeout(Duration.ofSeconds(15));
        return WebClient.builder()
                .clientConnector(new ReactorClientHttpConnector(httpClient))
                .build();
    }
}