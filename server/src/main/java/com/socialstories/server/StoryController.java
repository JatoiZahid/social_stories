package com.socialstories.server;

import java.io.IOException;
import java.io.InputStream;
import java.util.List;
import java.util.Map;

import jakarta.servlet.http.HttpServletRequest;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * The JSON API. Reading ({@code GET}) is open so the app can fetch stories;
 * changes need the admin token (see {@link Access}).
 */
@RestController
@RequestMapping("/api")
public class StoryController {

    private final StoryStore store;
    private final ImageLibrary images;

    public StoryController(StoryStore store, ImageLibrary images) {
        this.store = store;
        this.images = images;
    }

    // ── Public ───────────────────────────────────────────────────────────

    @GetMapping("/health")
    public Map<String, Object> health() {
        return Map.of("ok", true);
    }

    @GetMapping("/stories")
    public Story.Document stories() {
        return store.document();
    }

    @GetMapping("/stories/{id}")
    public Story story(@PathVariable String id) {
        return store.byId(id).orElseThrow(() -> ApiException.notFound(id));
    }

    @GetMapping("/images")
    public Map<String, Object> images() {
        return Map.of("images", images.list());
    }

    // ── Admin ────────────────────────────────────────────────────────────

    /** Lets the admin page check its token. */
    @GetMapping("/auth")
    @Access(Access.Level.ADMIN)
    public ResponseEntity<Void> auth() {
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/stories")
    @ResponseStatus(HttpStatus.CREATED)
    public Story create(@RequestBody Story story) {
        return store.create(story);
    }

    @PutMapping("/stories/{id}")
    public Story update(@PathVariable String id, @RequestBody Story story) {
        return store.update(id, story);
    }

    @DeleteMapping("/stories/{id}")
    public ResponseEntity<Void> delete(@PathVariable String id) {
        store.delete(id);
        return ResponseEntity.noContent().build();
    }

    public record OrderRequest(List<String> ids) {}

    /** Reorders the stories: {@code {"ids": [...]}} with every id once. */
    @PutMapping("/order")
    public Story.Document reorder(@RequestBody OrderRequest request) {
        store.reorder(request.ids());
        return store.document();
    }

    /** Uploads a picture sent as the raw request body (admin, or subscribers for their submissions). */
    @PostMapping("/images")
    @ResponseStatus(HttpStatus.CREATED)
    @Access(Access.Level.SUBSCRIBER)
    public Map<String, String> upload(HttpServletRequest request) throws IOException {
        byte[] bytes;
        try (InputStream in = request.getInputStream()) {
            bytes = in.readNBytes(ImageLibrary.MAX_UPLOAD_BYTES + 1); // +1 to notice "too big"
        }
        return Map.of("path", images.saveUpload(bytes));
    }
}
