package com.socialstories.server;

import java.nio.file.Path;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Settings from application.properties (prefix {@code stories.}).
 * Folders are plain strings (relative to the working folder), because
 * Spring's own Path conversion treats them as class path resources.
 */
@ConfigurationProperties("stories")
public record StoriesProperties(String dataDir, String appDir, String adminToken, GooglePlay googlePlay) {

    /** Google Play subscription checks. */
    public record GooglePlay(String packageName, String serviceAccountFile) {}

    public GooglePlay googlePlayOrDefault() {
        return googlePlay != null ? googlePlay : new GooglePlay("com.socialstories.social_stories", null);
    }

    public Path dataPath() {
        return Path.of(dataDir == null || dataDir.isBlank() ? "data" : dataDir);
    }

    public Path appPath() {
        return Path.of(appDir == null || appDir.isBlank() ? ".." : appDir);
    }

    public Path storiesFile() {
        return dataPath().resolve("stories.json");
    }

    public Path uploadsDir() {
        return dataPath().resolve("uploads");
    }

    /** The app's bundled stories, copied on the first start. */
    public Path seedFile() {
        return appPath().resolve("assets").resolve("data").resolve("stories.json");
    }

    public Path bundledImagesDir() {
        return appPath().resolve("assets").resolve("images").resolve("stories");
    }

    public Path sceneImagesDir() {
        return appPath().resolve("assets/images/story_scenes");
    }

    public Path spriteSheetsDir() {
        return appPath().resolve("assets/animations/spritesheets");
    }
}
