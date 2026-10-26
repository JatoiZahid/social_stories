package com.socialstories.server;

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.hasItems;
import static org.hamcrest.Matchers.startsWith;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import tools.jackson.databind.json.JsonMapper;

@SpringBootTest
@AutoConfigureMockMvc
class ApiTest {

    static final String TOKEN = "secret-token";
    static final byte[] PNG = {(byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0};
    static final Path ROOT = tempRoot();

    @Autowired MockMvc mvc;
    @Autowired JsonMapper json;

    /** A fake app folder (seed stories + one bundled picture) and an empty data folder. */
    static Path tempRoot() {
        try {
            Path root = Files.createTempDirectory("stories_test");
            Path images = Files.createDirectories(root.resolve("app/assets/images/stories"));
            Files.write(images.resolve("school.png"), PNG);
            Path data = Files.createDirectories(root.resolve("app/assets/data"));
            Files.writeString(data.resolve("stories.json"), """
                    {"version": 1, "stories": [{"id": "going_to_school", "title": "Going to School",
                      "pages": [{"image": "assets/images/stories/school.png", "lead": "First, we go.", "body": "Then we stay."}]}]}
                    """);
            return root;
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    @DynamicPropertySource
    static void properties(DynamicPropertyRegistry registry) {
        registry.add("stories.app-dir", () -> ROOT.resolve("app").toString());
        registry.add("stories.data-dir", () -> ROOT.resolve("data").toString());
        registry.add("stories.admin-token", () -> TOKEN);
    }

    static Map<String, Object> story(String id, String title, String image) {
        return Map.of("id", id, "title", title, "pages", List.of(
                Map.of("image", image, "lead", "First, we go.", "body", "Then we stay.")));
    }

    static Map<String, Object> story(String id) {
        return story(id, "A Story", "assets/images/stories/school.png");
    }

    MockHttpServletRequestBuilder admin(MockHttpServletRequestBuilder request) {
        return request.header("Authorization", "Bearer " + TOKEN);
    }

    MockHttpServletRequestBuilder withJson(MockHttpServletRequestBuilder request, Object body) {
        return admin(request).contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body));
    }

    @Test
    void startsWithTheSeededStoriesInTheAppFormat() throws Exception {
        mvc.perform(get("/api/stories"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.version").value(1))
                .andExpect(jsonPath("$.stories[?(@.id == 'going_to_school')].pages[0].id").value(hasItem("going_to_school-p1")));
        assert Files.exists(ROOT.resolve("data/stories.json"));
    }

    @Test
    void changesNeedTheAdminToken() throws Exception {
        mvc.perform(post("/api/stories").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(story("no_token"))))
                .andExpect(status().isUnauthorized());
        mvc.perform(delete("/api/stories/going_to_school")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/auth")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/auth").header("Authorization", "Bearer wrong")).andExpect(status().isUnauthorized());
        mvc.perform(admin(get("/api/auth"))).andExpect(status().isNoContent());
    }

    @Test
    void createReadUpdateAndDeleteAStory() throws Exception {
        mvc.perform(withJson(post("/api/stories"), story("haircut", "Getting a Haircut", "assets/images/stories/school.png")))
                .andExpect(status().isCreated());
        mvc.perform(withJson(post("/api/stories"), story("haircut")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value(containsString("already exists")));

        Map<String, Object> updated = Map.of("id", "ignored", "title", "Haircut Day", "pages", List.of(
                Map.of("image", "assets/images/stories/school.png", "lead", "We sit."),
                Map.of("image", "assets/images/stories/school.png", "lead", "Snip.", "body", "",
                        "focus", Map.of("x", 0.5, "y", -0.5, "zoom", 1.5))));
        mvc.perform(withJson(put("/api/stories/haircut"), updated))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value("haircut")) // the id in the URL wins
                .andExpect(jsonPath("$.title").value("Haircut Day"))
                .andExpect(jsonPath("$.pages[1].focus.zoom").value(1.5));

        mvc.perform(get("/api/stories/haircut"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.pages.length()").value(2));

        mvc.perform(admin(delete("/api/stories/haircut"))).andExpect(status().isNoContent());
        mvc.perform(get("/api/stories/haircut")).andExpect(status().isNotFound());
        mvc.perform(admin(delete("/api/stories/haircut"))).andExpect(status().isNotFound());
    }

    @Test
    void rejectsInvalidStories() throws Exception {
        List<Map<String, Object>> bad = List.of(
                story("Bad Id"),
                story("ok", "  ", "assets/images/stories/school.png"),
                Map.of("id", "ok", "title", "T", "pages", List.of()),
                story("ok", "T", "assets/images/stories/missing.png"),
                story("ok", "T", "../secret.png"),
                Map.of("id", "ok", "title", "T", "pages", List.of(Map.of(
                        "image", "assets/images/stories/school.png", "focus", Map.of("x", 3)))));
        for (Map<String, Object> story : bad) {
            mvc.perform(withJson(post("/api/stories"), story)).andExpect(status().isBadRequest());
        }
        mvc.perform(admin(post("/api/stories")).contentType(MediaType.APPLICATION_JSON).content("{nope"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").exists());
    }

    @Test
    void reordersStories() throws Exception {
        mvc.perform(withJson(post("/api/stories"), story("reorder_me"))).andExpect(status().isCreated());
        String body = mvc.perform(get("/api/stories")).andReturn().getResponse().getContentAsString();
        List<String> ids = new ArrayList<>();
        for (Story s : json.readValue(body, Story.Document.class).stories()) ids.add(s.id());
        Collections.reverse(ids);

        mvc.perform(withJson(put("/api/order"), Map.of("ids", ids)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.stories[0].id").value(ids.get(0)));
        mvc.perform(withJson(put("/api/order"), Map.of("ids", List.of(ids.get(0)))))
                .andExpect(status().isBadRequest());
    }

    @Test
    void uploadsAPictureAndUsesItInAStory() throws Exception {
        mvc.perform(admin(post("/api/images")).contentType(MediaType.IMAGE_PNG).content("not an image"))
                .andExpect(status().isBadRequest());

        String body = mvc.perform(admin(post("/api/images")).contentType(MediaType.IMAGE_PNG).content(PNG))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.path").value(startsWith("uploads/")))
                .andReturn().getResponse().getContentAsString();
        String path = json.readTree(body).get("path").asString();

        mvc.perform(get("/" + path)).andExpect(status().isOk());
        mvc.perform(get("/assets/images/stories/school.png")).andExpect(status().isOk());
        mvc.perform(get("/api/images"))
                .andExpect(jsonPath("$.images[*].path").value(hasItems("assets/images/stories/school.png", path)));
        mvc.perform(withJson(post("/api/stories"), story("with_upload", "Upload", path)))
                .andExpect(status().isCreated());
    }

    @Test
    void servesTheAdminPage() throws Exception {
        mvc.perform(get("/index.html"))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("Social Stories Admin")));
    }

    @Test
    void preservesSituationAnimationAndAnswerImages() throws Exception {
        Path sceneDir = Files.createDirectories(ROOT.resolve("app/assets/images/story_scenes"));
        Path spriteDir = Files.createDirectories(ROOT.resolve("app/assets/animations/spritesheets"));
        Files.write(sceneDir.resolve("brush.png"), PNG);
        Files.write(spriteDir.resolve("brush.png"), PNG);
        Map<String, Object> animation = Map.of("asset", "assets/animations/spritesheets/brush.png",
                "columns", 2, "rows", 1, "row", 0, "frameCount", 2,
                "fps", 2, "posterFrame", 1, "cue", "brush", "loop", false,
                "frameCues", List.of("We", "brush"));
        Map<String, Object> story = Map.of("id", "animated", "title", "Brush",
                "pages", List.of(Map.of("image", "assets/images/story_scenes/brush.png", "lead", "We brush.",
                        "animation", animation)),
                "questions", List.of(Map.of("question", "Which picture?", "choices", List.of("Brush", "Other"),
                        "answer", 0, "choiceImages", java.util.Arrays.asList("assets/images/story_scenes/brush.png", null))));
        mvc.perform(withJson(post("/api/stories"), story)).andExpect(status().isCreated())
                .andExpect(jsonPath("$.pages[0].animation.frameCount").value(2))
                .andExpect(jsonPath("$.pages[0].animation.loop").value(false))
                .andExpect(jsonPath("$.pages[0].animation.frameCues[1]").value("brush"))
                .andExpect(jsonPath("$.questions[0].choiceImages[0]").value("assets/images/story_scenes/brush.png"));
        mvc.perform(get("/api/stories/animated")).andExpect(status().isOk())
                .andExpect(jsonPath("$.pages[0].animation.cue").value("brush"));
        mvc.perform(get("/assets/animations/spritesheets/brush.png")).andExpect(status().isOk());
        mvc.perform(get("/assets/images/story_scenes/brush.png")).andExpect(status().isOk());
        Map<String, Object> badAnimation = new java.util.HashMap<>(animation);
        badAnimation.put("frameCount", 3);
        mvc.perform(withJson(post("/api/stories"), Map.of("id", "bad_atlas", "title", "Bad",
                "pages", List.of(Map.of("image", "assets/images/story_scenes/brush.png", "lead", "We brush.",
                        "animation", badAnimation))))).andExpect(status().isBadRequest());
        badAnimation.put("frameCount", 2);
        badAnimation.put("frameCues", List.of("brush", "We"));
        mvc.perform(withJson(post("/api/stories"), Map.of("id", "bad_cues", "title", "Bad",
                "pages", List.of(Map.of("image", "assets/images/story_scenes/brush.png", "lead", "We brush.",
                        "animation", badAnimation))))).andExpect(status().isBadRequest());
    }
}
