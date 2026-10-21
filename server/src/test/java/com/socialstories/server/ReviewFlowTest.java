package com.socialstories.server;

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.not;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.nio.file.Path;
import java.time.LocalDate;
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
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/** Accounts, subscriptions, sending changes for review and approving them. */
@SpringBootTest
@AutoConfigureMockMvc
class ReviewFlowTest {

    static final String ADMIN = "admin-secret";
    static final Path ROOT = ApiTest.tempRoot();
    static final String IMAGE = "assets/images/stories/school.png";

    @Autowired MockMvc mvc;
    @Autowired JsonMapper json;

    @DynamicPropertySource
    static void properties(DynamicPropertyRegistry registry) {
        registry.add("stories.app-dir", () -> ROOT.resolve("app").toString());
        registry.add("stories.data-dir", () -> ROOT.resolve("data").toString());
        registry.add("stories.admin-token", () -> ADMIN);
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    ResultActions call(MockHttpServletRequestBuilder request, String token, Object body) throws Exception {
        if (token != null) request.header("Authorization", "Bearer " + token);
        if (body != null) request.contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body));
        return mvc.perform(request);
    }

    JsonNode read(ResultActions result) throws Exception {
        return json.readTree(result.andReturn().getResponse().getContentAsString());
    }

    /** Registers a user and returns [token, userId]. */
    String[] register(String email) throws Exception {
        JsonNode body = read(call(post("/api/auth/register"), null,
                Map.of("email", email, "password", "password123", "name", "Sam")).andExpect(status().isCreated()));
        return new String[] {body.get("token").asString(), body.get("user").get("id").asString()};
    }

    /** A registered user with an admin-granted subscription. Returns their token. */
    String subscriber(String email) throws Exception {
        String[] user = register(email);
        call(put("/api/admin/users/" + user[1] + "/subscription"), ADMIN, Map.of("active", true))
                .andExpect(status().isOk());
        return user[0];
    }

    static Map<String, Object> page(String lead) {
        return Map.of("image", IMAGE, "lead", lead, "body", "More detail.");
    }

    static Map<String, Object> question(String text, int answer) {
        return Map.of("question", text, "choices", List.of("Yes", "No", "Maybe"), "answer", answer);
    }

    Map<String, Object> submission(String type, String storyId, Map<String, Object> story) {
        return storyId == null ? Map.of("type", type, "story", story) : Map.of("type", type, "storyId", storyId, "story", story);
    }

    // ── Accounts ─────────────────────────────────────────────────────────

    @Test
    void registerSignInAndSignOut() throws Exception {
        String[] user = register("Parent@Example.com");
        call(get("/api/me"), user[0], null)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.email").value("parent@example.com"))
                .andExpect(jsonPath("$.subscription.active").value(false))
                .andExpect(jsonPath("$.passwordHash").doesNotExist());

        call(post("/api/auth/register"), null, Map.of("email", "parent@example.com", "password", "password123"))
                .andExpect(status().isConflict());
        call(post("/api/auth/register"), null, Map.of("email", "short@example.com", "password", "short"))
                .andExpect(status().isBadRequest());
        call(post("/api/auth/register"), null, Map.of("email", "not-an-email", "password", "password123"))
                .andExpect(status().isBadRequest());

        call(post("/api/auth/login"), null, Map.of("email", "parent@example.com", "password", "wrong-password"))
                .andExpect(status().isUnauthorized());
        String token = read(call(post("/api/auth/login"), null,
                Map.of("email", "parent@example.com", "password", "password123")).andExpect(status().isOk()))
                .get("token").asString();

        call(post("/api/auth/logout"), token, null).andExpect(status().isNoContent());
        call(get("/api/me"), token, null).andExpect(status().isUnauthorized());
        call(get("/api/me"), user[0], null).andExpect(status().isOk()); // other sessions stay signed in
    }

    @Test
    void usersCannotUseAdminEndpoints() throws Exception {
        String token = subscriber("not-admin@example.com");
        call(get("/api/admin/submissions"), token, null).andExpect(status().isUnauthorized());
        call(get("/api/admin/users"), null, null).andExpect(status().isUnauthorized());
        call(post("/api/stories"), token, Map.of("id", "x", "title", "X", "pages", List.of(page("Hi."))))
                .andExpect(status().isUnauthorized());
    }

    // ── Subscriptions ────────────────────────────────────────────────────

    @Test
    void onlySubscribersCanSendChanges() throws Exception {
        String[] user = register("free@example.com");
        Map<String, Object> story = Map.of("title", "My Story", "pages", List.of(page("Hello.")));

        call(post("/api/submissions"), user[0], submission("new_story", null, story))
                .andExpect(status().isForbidden());
        call(post("/api/submissions"), null, submission("new_story", null, story))
                .andExpect(status().isUnauthorized());

        String tomorrow = LocalDate.now().plusDays(1).toString();
        call(put("/api/admin/users/" + user[1] + "/subscription"), ADMIN, Map.of("active", true, "until", tomorrow))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.subscription.active").value(true))
                .andExpect(jsonPath("$.subscription.source").value("admin"));
        call(post("/api/submissions"), user[0], submission("new_story", null, story)).andExpect(status().isCreated());

        call(put("/api/admin/users/" + user[1] + "/subscription"), ADMIN, Map.of("active", true, "until", "2001-01-01"))
                .andExpect(status().isBadRequest());
        call(put("/api/admin/users/" + user[1] + "/subscription"), ADMIN, Map.of("active", false))
                .andExpect(jsonPath("$.subscription.active").value(false));
        call(post("/api/submissions"), user[0], submission("new_story", null, story)).andExpect(status().isForbidden());
    }

    @Test
    void googlePlayNeedsServerSetup() throws Exception {
        String[] user = register("play@example.com");
        call(post("/api/me/google-play"), user[0], Map.of("productId", "sub", "purchaseToken", "abc"))
                .andExpect(status().isServiceUnavailable());
    }

    // ── Review ───────────────────────────────────────────────────────────

    @Test
    void aNewStoryIsPublishedOnlyAfterApproval() throws Exception {
        String token = subscriber("writer@example.com");
        Map<String, Object> story = Map.of("title", "Visiting Grandma",
                "pages", List.of(page("We drive to Grandma's house."), page("We give her a hug.")),
                "questions", List.of(question("Do we hug Grandma?", 0)));

        String id = read(call(post("/api/submissions"), token, submission("new_story", null, story))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("pending"))).get("id").asString();

        call(get("/api/stories"), null, null).andExpect(jsonPath("$.stories[*].title", not(hasItem("Visiting Grandma"))));
        call(get("/api/admin/submissions"), ADMIN, null)
                .andExpect(jsonPath("$[*].id", hasItem(id)));

        call(post("/api/admin/submissions/" + id + "/approve"), ADMIN, Map.of("note", "Lovely!"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("approved"))
                .andExpect(jsonPath("$.storyId").value("visiting_grandma"));

        call(get("/api/stories/visiting_grandma"), null, null)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.pages.length()").value(2))
                .andExpect(jsonPath("$.pages[0].id").value("visiting_grandma-p1"))
                .andExpect(jsonPath("$.questions[0].answer").value(0));
        call(get("/api/me/submissions"), token, null)
                .andExpect(jsonPath("$[0].status").value("approved"))
                .andExpect(jsonPath("$[0].reviewNote").value("Lovely!"));

        call(post("/api/admin/submissions/" + id + "/approve"), ADMIN, null).andExpect(status().isConflict());
    }

    @Test
    void editsCanBeReplacedRejectedOrWithdrawn() throws Exception {
        String token = subscriber("editor@example.com");
        Map<String, Object> edit1 = Map.of("title", "Going to School!", "pages", List.of(page("First edit.")));
        Map<String, Object> edit2 = Map.of("title", "Going to School!!", "pages", List.of(page("Second edit.")));

        String first = read(call(post("/api/submissions"), token, submission("edit_story", "going_to_school", edit1))
                .andExpect(status().isCreated())).get("id").asString();
        String second = read(call(post("/api/submissions"), token, submission("edit_story", "going_to_school", edit2))
                .andExpect(status().isCreated())).get("id").asString();
        assert first.equals(second) : "sending the same edit again replaces the waiting one";

        call(get("/api/admin/submissions/" + first), ADMIN, null)
                .andExpect(jsonPath("$.proposed.title").value("Going to School!!"))
                .andExpect(jsonPath("$.base.title").value("Going to School"))
                .andExpect(jsonPath("$.submittedBy.email").value("editor@example.com"));

        call(post("/api/admin/submissions/" + first + "/reject"), ADMIN, Map.of("note", "Please keep the original title."))
                .andExpect(jsonPath("$.status").value("rejected"));
        call(get("/api/stories/going_to_school"), null, null).andExpect(jsonPath("$.title").value("Going to School"));
        call(get("/api/me/submissions"), token, null)
                .andExpect(jsonPath("$[0].reviewNote").value("Please keep the original title."));

        String third = read(call(post("/api/submissions"), token, submission("edit_story", "going_to_school", edit1))
                .andExpect(status().isCreated())).get("id").asString();
        call(delete("/api/me/submissions/" + third), token, null).andExpect(jsonPath("$.status").value("withdrawn"));
        call(post("/api/admin/submissions/" + third + "/approve"), ADMIN, null).andExpect(status().isConflict());

        Map<String, Object> unchanged = Map.of("title", "Going to School",
                "pages", List.of(Map.of("image", IMAGE, "lead", "First, we go.", "body", "Then we stay.")));
        call(post("/api/submissions"), token, submission("edit_story", "going_to_school", unchanged))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value(containsString("Nothing has changed")));
    }

    @Test
    void questionsGoThroughReviewToo() throws Exception {
        String token = subscriber("quiz@example.com");
        call(post("/api/stories"), ADMIN, Map.of("id", "quiz_story", "title", "Quiz Story", "pages", List.of(page("Hi."))))
                .andExpect(status().isCreated());

        Map<String, Object> bad = Map.of("questions", List.of(question("Which one?", 7)));
        call(post("/api/submissions"), token, submission("edit_questions", "quiz_story", bad))
                .andExpect(status().isBadRequest());
        Map<String, Object> twoChoicesMin = Map.of("questions", List.of(
                Map.of("question", "Only one?", "choices", List.of("Yes"), "answer", 0)));
        call(post("/api/submissions"), token, submission("edit_questions", "quiz_story", twoChoicesMin))
                .andExpect(status().isBadRequest());

        Map<String, Object> good = Map.of("title", "Ignored", "questions", List.of(
                question("Do we say hi?", 0), question("Do we shout?", 1)));
        String id = read(call(post("/api/submissions"), token, submission("edit_questions", "quiz_story", good))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.proposed.title").value("Quiz Story"))).get("id").asString();

        call(get("/api/stories/quiz_story"), null, null).andExpect(jsonPath("$.questions").doesNotExist());
        call(post("/api/admin/submissions/" + id + "/approve"), ADMIN, null).andExpect(status().isOk());
        call(get("/api/stories/quiz_story"), null, null)
                .andExpect(jsonPath("$.title").value("Quiz Story"))
                .andExpect(jsonPath("$.questions.length()").value(2))
                .andExpect(jsonPath("$.questions[1].choices[1]").value("No"));

        // The web admin page saves stories without touching their questions.
        call(put("/api/stories/quiz_story"), ADMIN, Map.of("title", "Quiz Story 2", "pages", List.of(page("Hi."))))
                .andExpect(jsonPath("$.questions.length()").value(2));
    }

    @Test
    void reviewerIsWarnedWhenTheStoryChangedMeanwhile() throws Exception {
        String token = subscriber("late@example.com");
        call(post("/api/stories"), ADMIN, Map.of("id", "busy_story", "title", "Busy", "pages", List.of(page("One."))))
                .andExpect(status().isCreated());
        String id = read(call(post("/api/submissions"), token, submission("edit_story", "busy_story",
                Map.of("title", "Busy Day", "pages", List.of(page("One."))))).andExpect(status().isCreated()))
                .get("id").asString();
        call(get("/api/admin/submissions/" + id), ADMIN, null).andExpect(jsonPath("$.outdated").value(false));

        call(put("/api/stories/busy_story"), ADMIN, Map.of("title", "Busy", "pages", List.of(page("Changed by admin."))))
                .andExpect(status().isOk());
        call(get("/api/admin/submissions/" + id), ADMIN, null).andExpect(jsonPath("$.outdated").value(true));

        call(delete("/api/stories/busy_story"), ADMIN, null).andExpect(status().isNoContent());
        call(post("/api/admin/submissions/" + id + "/approve"), ADMIN, null).andExpect(status().isConflict());
    }

    @Test
    void subscribersCanUploadPicturesForTheirStories() throws Exception {
        String[] free = register("free-upload@example.com");
        mvc.perform(post("/api/images").header("Authorization", "Bearer " + free[0])
                .contentType(MediaType.IMAGE_PNG).content(ApiTest.PNG)).andExpect(status().isForbidden());
        String token = subscriber("upload@example.com");
        mvc.perform(post("/api/images").header("Authorization", "Bearer " + token)
                .contentType(MediaType.IMAGE_PNG).content(ApiTest.PNG)).andExpect(status().isCreated());
    }

    @Test
    void summaryCountsPendingAndSubscribers() throws Exception {
        call(get("/api/admin/summary"), ADMIN, null)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.pending").exists())
                .andExpect(jsonPath("$.subscribers").exists());
        call(get("/api/admin/users"), ADMIN, null).andExpect(jsonPath("$..passwordHash").isEmpty());
    }
}
