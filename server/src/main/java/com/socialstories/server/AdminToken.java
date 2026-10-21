package com.socialstories.server;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.SecureRandom;

import org.springframework.stereotype.Component;

/**
 * The admin page password: {@code stories.admin-token} (ADMIN_TOKEN) if set,
 * otherwise generated once and saved in data/admin_token.txt.
 */
@Component
public class AdminToken {

    private static final String CHARS = "abcdefghjkmnpqrstuvwxyz23456789";

    private final String value;

    public AdminToken(StoriesProperties properties) throws IOException {
        String configured = properties.adminToken();
        if (configured != null && !configured.isBlank()) {
            value = configured.trim();
            return;
        }
        Path file = properties.dataPath().resolve("admin_token.txt");
        String saved = Files.exists(file) ? Files.readString(file).trim() : "";
        if (!saved.isEmpty()) {
            value = saved;
            return;
        }
        SecureRandom random = new SecureRandom();
        StringBuilder token = new StringBuilder();
        for (int i = 0; i < 16; i++) token.append(CHARS.charAt(random.nextInt(CHARS.length())));
        value = token.toString();
        Files.createDirectories(properties.dataPath());
        Files.writeString(file, value);
    }

    public String value() {
        return value;
    }
}
