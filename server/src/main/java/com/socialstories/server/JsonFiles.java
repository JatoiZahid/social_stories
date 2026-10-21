package com.socialstories.server;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;

import tools.jackson.databind.json.JsonMapper;

/** Saving and loading the server's JSON data files. */
final class JsonFiles {

    private JsonFiles() {}

    /** Writes to a temp file first so a crash never leaves a half-written file. */
    static void write(JsonMapper json, Path file, Object value) {
        try {
            String text = json.writerWithDefaultPrettyPrinter().writeValueAsString(value);
            Path dir = file.toAbsolutePath().getParent();
            Files.createDirectories(dir);
            Path tmp = dir.resolve(file.getFileName() + ".tmp");
            Files.writeString(tmp, text);
            Files.move(tmp, file, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
        } catch (IOException e) {
            throw new UncheckedIOException("Could not save " + file, e);
        }
    }

    /** Reads {@code file}, or returns null if it does not exist yet. */
    static <T> T read(JsonMapper json, Path file, Class<T> type) {
        if (!Files.exists(file)) return null;
        try {
            return json.readValue(Files.readString(file), type);
        } catch (IOException e) {
            throw new UncheckedIOException("Could not read " + file, e);
        }
    }
}
