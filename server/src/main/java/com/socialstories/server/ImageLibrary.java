package com.socialstories.server;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.SecureRandom;
import java.util.ArrayList;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;
import java.util.stream.Stream;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/**
 * Where story pictures come from:
 * <ul>
 *   <li>{@code assets/images/stories/<file>}: bundled with the app</li>
 *   <li>{@code uploads/<file>}: uploaded through the admin page</li>
 * </ul>
 */
@Component
public class ImageLibrary {

    public static final String BUNDLED_PREFIX = "assets/images/stories/";
    public static final String UPLOADS_PREFIX = "uploads/";
    public static final int MAX_UPLOAD_BYTES = 5 * 1024 * 1024;

    private static final Pattern FILE_NAME = Pattern.compile("^[A-Za-z0-9][A-Za-z0-9_.-]*\\.(png|jpe?g|webp)$");
    private static final SecureRandom RANDOM = new SecureRandom();

    private final Path bundledDir;
    private final Path uploadsDir;

    public ImageLibrary(StoriesProperties properties) {
        this.bundledDir = properties.bundledImagesDir();
        this.uploadsDir = properties.uploadsDir();
        try {
            Files.createDirectories(uploadsDir);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    public Path bundledDir() {
        return bundledDir;
    }

    public Path uploadsDir() {
        return uploadsDir;
    }

    /** True if {@code path} points at a picture that exists. */
    public boolean exists(String path) {
        Path file = fileFor(path);
        return file != null && Files.isRegularFile(file);
    }

    /** The file behind an image path, or null if the path is not allowed. */
    Path fileFor(String path) {
        if (path == null) return null;
        for (var entry : List.of(Map.entry(BUNDLED_PREFIX, bundledDir), Map.entry(UPLOADS_PREFIX, uploadsDir))) {
            if (!path.startsWith(entry.getKey())) continue;
            String name = path.substring(entry.getKey().length());
            return FILE_NAME.matcher(name).matches() ? entry.getValue().resolve(name) : null;
        }
        return null;
    }

    /** Every picture the admin page can choose from. */
    public List<Map<String, String>> list() {
        List<Map<String, String>> all = new ArrayList<>();
        all.addAll(listDir(bundledDir, BUNDLED_PREFIX, "bundled"));
        all.addAll(listDir(uploadsDir, UPLOADS_PREFIX, "uploaded"));
        return all;
    }

    private static List<Map<String, String>> listDir(Path dir, String prefix, String source) {
        if (!Files.isDirectory(dir)) return List.of();
        try (Stream<Path> files = Files.list(dir)) {
            return files
                    .filter(Files::isRegularFile)
                    .map(f -> f.getFileName().toString())
                    .filter(name -> FILE_NAME.matcher(name).matches())
                    .sorted()
                    .map(name -> Map.of("path", prefix + name, "name", prettyName(name), "source", source))
                    .toList();
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    private static String prettyName(String file) {
        String stem = file.replaceFirst("\\.[^.]+$", "").replaceAll("[_-]+", " ").trim();
        return stem.isEmpty() ? file : Character.toUpperCase(stem.charAt(0)) + stem.substring(1);
    }

    /** Saves an uploaded picture and returns its image path ({@code uploads/...}). */
    public String saveUpload(byte[] bytes) throws IOException {
        if (bytes.length == 0) throw ApiException.invalid("The picture is empty.");
        if (bytes.length > MAX_UPLOAD_BYTES) {
            throw new ApiException(HttpStatus.CONTENT_TOO_LARGE,
                    "The picture is too big (max " + MAX_UPLOAD_BYTES / (1024 * 1024) + " MB).");
        }
        String ext = sniffExtension(bytes);
        if (ext == null) throw ApiException.invalid("Only PNG, JPEG and WebP pictures are supported.");

        byte[] random = new byte[6];
        RANDOM.nextBytes(random);
        String name = Long.toString(System.currentTimeMillis(), 36) + "-" + HexFormat.of().formatHex(random) + "." + ext;
        Files.createDirectories(uploadsDir);
        Files.write(uploadsDir.resolve(name), bytes);
        return UPLOADS_PREFIX + name;
    }

    /** Checks the file's first bytes rather than trusting the browser. */
    static String sniffExtension(byte[] b) {
        if (startsWith(b, 0, 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)) return "png";
        if (startsWith(b, 0, 0xFF, 0xD8, 0xFF)) return "jpg";
        if (startsWith(b, 0, 0x52, 0x49, 0x46, 0x46) && startsWith(b, 8, 0x57, 0x45, 0x42, 0x50)) return "webp";
        return null;
    }

    private static boolean startsWith(byte[] b, int offset, int... signature) {
        if (b.length < offset + signature.length) return false;
        for (int i = 0; i < signature.length; i++) {
            if ((b[offset + i] & 0xFF) != signature[i]) return false;
        }
        return true;
    }
}
