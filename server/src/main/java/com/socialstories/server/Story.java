package com.socialstories.server;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonPropertyOrder;

/**
 * A social story, in the same JSON format as the app's assets/data/stories.json.
 * {@code questions} is the multiple-choice quiz shown after the last page.
 */
@JsonPropertyOrder({"id", "title", "pages", "questions"})
public record Story(
        String id,
        String title,
        List<Page> pages,
        @JsonInclude(JsonInclude.Include.NON_EMPTY) List<Question> questions) {

    /** One page: a picture plus two short sentences. */
    @JsonInclude(JsonInclude.Include.NON_NULL)
    @JsonPropertyOrder({"id", "image", "lead", "body", "focus", "animation"})
    public record Page(String id, String image, String lead, String body, Focus focus, Animation animation) {
        public Page(String id, String image, String lead, String body, Focus focus) {
            this(id, image, lead, body, focus, null);
        }
    }

    /** A fixed-grid sprite atlas; each row holds one situation's action frames. */
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public record Animation(String asset, Integer columns, Integer rows, Integer row,
                            Integer frameCount, Double fps, Integer posterFrame,
                            String cue, String description, Boolean loop,
                            @JsonInclude(JsonInclude.Include.NON_EMPTY) List<String> frameCues) {}

    /** Optional zoom into part of the picture (x/y from -1 to 1, zoom 1 = whole picture). */
    @JsonPropertyOrder({"x", "y", "zoom"})
    public record Focus(Double x, Double y, Double zoom) {}

    /** A quiz question: 2–4 choices, {@code answer} is the index of the right one. */
    @JsonPropertyOrder({"id", "question", "choices", "answer", "choiceImages"})
    public record Question(String id, String question, List<String> choices, Integer answer,
                           @JsonInclude(JsonInclude.Include.NON_EMPTY) List<String> choiceImages) {
        public Question(String id, String question, List<String> choices, Integer answer) {
            this(id, question, choices, answer, null);
        }
    }

    /** The whole file / the {@code GET /api/stories} response. */
    @JsonPropertyOrder({"version", "updatedAt", "stories"})
    public record Document(int version, String updatedAt, List<Story> stories) {}

    public List<Question> questionsOrEmpty() {
        return questions == null ? List.of() : questions;
    }
}
