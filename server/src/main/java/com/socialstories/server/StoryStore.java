package com.socialstories.server;

import java.text.Normalizer;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.regex.Pattern;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import tools.jackson.databind.json.JsonMapper;

/**
 * The published stories, saved as one JSON file in the same format as the
 * app's assets/data/stories.json, so the app can read it directly.
 * All methods are synchronized: one change at a time.
 */
@Component
public class StoryStore {

    static final Pattern ID = Pattern.compile("^[a-z0-9][a-z0-9_-]{0,63}$");
    static final int MAX_TITLE = 120;
    static final int MAX_TEXT = 500;
    static final int MAX_PAGES = 100;
    static final int MAX_QUESTIONS = 10;
    static final int MAX_QUESTION = 200;
    static final int MAX_CHOICE = 100;

    private static final Logger log = LoggerFactory.getLogger(StoryStore.class);

    private final java.nio.file.Path file;
    private final ImageLibrary images;
    private final JsonMapper json;
    private final List<Story> stories = new ArrayList<>();
    private Instant updatedAt = Instant.now();

    public StoryStore(StoriesProperties properties, ImageLibrary images, JsonMapper json) {
        this.file = properties.storiesFile();
        this.images = images;
        this.json = json;

        // First start: copy the stories bundled with the app.
        boolean exists = java.nio.file.Files.exists(file);
        Story.Document doc = JsonFiles.read(json, exists ? file : properties.seedFile(), Story.Document.class);
        if (doc == null) {
            log.warn("No stories found at {}. Starting with an empty list.", properties.seedFile().toAbsolutePath());
        } else {
            if (doc.stories() != null) {
                // Seeded data is trusted for pictures (they may live elsewhere),
                // but still gets the same clean-up as API input.
                for (Story story : doc.stories()) stories.add(clean(story, story.id(), false));
            }
            if (doc.updatedAt() != null) updatedAt = Instant.parse(doc.updatedAt());
        }
        if (!exists) save();
    }

    public synchronized Story.Document document() {
        return new Story.Document(1, updatedAt.toString(), List.copyOf(stories));
    }

    public synchronized Optional<Story> byId(String id) {
        return stories.stream().filter(s -> s.id().equals(id)).findFirst();
    }

    // ── Admin edits (web admin page) ────────────────────────────────────

    public synchronized Story create(Story input) {
        if (input == null) throw ApiException.invalid("A story must be a JSON object.");
        Story story = clean(input, input.id(), true);
        if (byId(story.id()).isPresent()) {
            throw ApiException.invalid("A story with id \"" + story.id() + "\" already exists.");
        }
        stories.add(story);
        save();
        return story;
    }

    /**
     * Replaces story {@code id}. The id itself cannot change. If the input has
     * no {@code questions}, the story keeps the questions it has.
     */
    public synchronized Story update(String id, Story input) {
        int index = indexOf(id);
        if (index == -1) throw ApiException.notFound(id);
        if (input == null) throw ApiException.invalid("A story must be a JSON object.");
        List<Story.Question> questions = input.questions() != null ? input.questions() : stories.get(index).questions();
        Story story = clean(new Story(id, input.title(), input.pages(), questions), id, true);
        stories.set(index, story);
        save();
        return story;
    }

    public synchronized void delete(String id) {
        int index = indexOf(id);
        if (index == -1) throw ApiException.notFound(id);
        stories.remove(index);
        save();
    }

    /** {@code ids} must list every story exactly once, in the new order. */
    public synchronized void reorder(List<String> ids) {
        if (ids == null || ids.contains(null)) throw ApiException.invalid("\"ids\" must be a list of story ids.");
        Map<String, Story> current = new LinkedHashMap<>();
        for (Story s : stories) current.put(s.id(), s);
        if (ids.size() != current.size() || !new HashSet<>(ids).containsAll(current.keySet())) {
            throw ApiException.invalid("\"ids\" must list every story exactly once.");
        }
        List<Story> ordered = ids.stream().map(current::get).toList();
        stories.clear();
        stories.addAll(ordered);
        save();
    }

    // ── Publishing approved submissions ─────────────────────────────────

    /** Adds a new story with an id made from its title. */
    public synchronized Story publishNew(Story proposal) {
        String base = slug(proposal.title());
        String id = base;
        for (int n = 2; byId(id).isPresent(); n++) id = base + "_" + n;
        // Drop the placeholder ids so pages and questions get ids from the real story id.
        List<Story.Page> pages = proposal.pages().stream()
                .map(p -> new Story.Page(null, p.image(), p.lead(), p.body(), p.focus())).toList();
        List<Story.Question> questions = proposal.questionsOrEmpty().stream()
                .map(q -> new Story.Question(null, q.question(), q.choices(), q.answer())).toList();
        Story story = clean(new Story(id, proposal.title(), pages, questions), id, true);
        stories.add(story);
        save();
        return story;
    }

    /** Applies a new title and pages; the story keeps its questions. */
    public synchronized Story publishEdit(String id, Story proposal) {
        int index = indexOf(id);
        if (index == -1) throw gone(id);
        Story story = clean(new Story(id, proposal.title(), proposal.pages(), stories.get(index).questions()), id, true);
        stories.set(index, story);
        save();
        return story;
    }

    /** Applies new questions; title and pages stay as they are. */
    public synchronized Story publishQuestions(String id, List<Story.Question> questions) {
        int index = indexOf(id);
        if (index == -1) throw gone(id);
        Story current = stories.get(index);
        Story story = clean(new Story(id, current.title(), current.pages(), questions), id, true);
        stories.set(index, story);
        save();
        return story;
    }

    private static ApiException gone(String id) {
        return new ApiException(HttpStatus.CONFLICT, "Story \"" + id + "\" was deleted, so this change can't be applied.");
    }

    /** Checks a story someone wants to submit, using {@code id} as its id. */
    public Story validate(Story input, String id) {
        if (input == null) throw ApiException.invalid("A story must be a JSON object.");
        return clean(input, id, true);
    }

    private int indexOf(String id) {
        for (int i = 0; i < stories.size(); i++) {
            if (stories.get(i).id().equals(id)) return i;
        }
        return -1;
    }

    private void save() {
        updatedAt = Instant.now();
        JsonFiles.write(json, file, document());
    }

    static String slug(String title) {
        String s = Normalizer.normalize(title == null ? "" : title, Normalizer.Form.NFKD)
                .toLowerCase()
                .replaceAll("[^a-z0-9]+", "_")
                .replaceAll("^_+|_+$", "");
        if (s.length() > 56) s = s.substring(0, 56);
        return s.isEmpty() ? "story" : s;
    }

    // ── Validation ──────────────────────────────────────────────────────

    /** Validates a story and keeps only the known fields. */
    private Story clean(Story input, String id, boolean checkImages) {
        if (id == null || !ID.matcher(id).matches()) {
            throw ApiException.invalid("Story id must be 1-64 characters: lowercase letters, numbers, \"-\" or \"_\".");
        }
        String title = text(input.title(), "title", MAX_TITLE).trim();
        if (title.isEmpty()) throw ApiException.invalid("The story needs a title.");

        List<Story.Page> raw = input.pages();
        if (raw == null || raw.isEmpty()) throw ApiException.invalid("The story needs at least one page.");
        if (raw.size() > MAX_PAGES) throw ApiException.invalid("A story can have at most " + MAX_PAGES + " pages.");

        List<Story.Page> pages = new ArrayList<>();
        Set<String> pageIds = new HashSet<>();
        for (int i = 0; i < raw.size(); i++) {
            String where = "Page " + (i + 1);
            Story.Page page = raw.get(i);
            if (page == null) throw ApiException.invalid(where + " must be a JSON object.");

            String image = page.image();
            if (image == null || image.isEmpty()) throw ApiException.invalid(where + " needs a picture.");
            if (checkImages && !images.exists(image)) {
                throw ApiException.invalid(where + " uses a picture that does not exist: " + image);
            }
            String pageId = uniqueId(page.id(), id + "-p" + (i + 1), pageIds);
            pages.add(new Story.Page(
                    pageId,
                    image,
                    text(page.lead(), where + " main sentence", MAX_TEXT),
                    text(page.body(), where + " detail", MAX_TEXT),
                    focus(page.focus(), where)));
        }
        return new Story(id, title, List.copyOf(pages), questions(input.questions(), id));
    }

    private static List<Story.Question> questions(List<Story.Question> raw, String storyId) {
        if (raw == null || raw.isEmpty()) return List.of();
        if (raw.size() > MAX_QUESTIONS) throw ApiException.invalid("A story can have at most " + MAX_QUESTIONS + " questions.");
        List<Story.Question> out = new ArrayList<>();
        Set<String> ids = new HashSet<>();
        for (int i = 0; i < raw.size(); i++) {
            String where = "Question " + (i + 1);
            Story.Question q = raw.get(i);
            if (q == null) throw ApiException.invalid(where + " must be a JSON object.");
            String question = text(q.question(), where, MAX_QUESTION).trim();
            if (question.isEmpty()) throw ApiException.invalid(where + " needs some text.");
            List<String> choices = q.choices();
            if (choices == null || choices.size() < 2 || choices.size() > 4) {
                throw ApiException.invalid(where + " needs 2 to 4 answer choices.");
            }
            List<String> cleanChoices = new ArrayList<>();
            for (int c = 0; c < choices.size(); c++) {
                String choice = text(choices.get(c), where + " choice " + (c + 1), MAX_CHOICE).trim();
                if (choice.isEmpty()) throw ApiException.invalid(where + " choice " + (c + 1) + " is empty.");
                cleanChoices.add(choice);
            }
            Integer answer = q.answer();
            if (answer == null || answer < 0 || answer >= cleanChoices.size()) {
                throw ApiException.invalid(where + " needs a correct answer.");
            }
            out.add(new Story.Question(uniqueId(q.id(), storyId + "-q" + (i + 1), ids), question,
                    List.copyOf(cleanChoices), answer));
        }
        return List.copyOf(out);
    }

    private static String uniqueId(String given, String fallback, Set<String> taken) {
        String id = given == null || given.isBlank() || given.length() > 80 || taken.contains(given) ? fallback : given;
        while (taken.contains(id)) id = id + "x";
        taken.add(id);
        return id;
    }

    private static Story.Focus focus(Story.Focus focus, String where) {
        if (focus == null) return null;
        double x = number(focus.x(), 0, where + " focus x", -1, 1);
        double y = number(focus.y(), 0, where + " focus y", -1, 1);
        double zoom = number(focus.zoom(), 1, where + " zoom", 1, 4);
        return x == 0 && y == 0 && zoom == 1 ? null : new Story.Focus(x, y, zoom);
    }

    private static String text(String value, String field, int max) {
        if (value == null) return "";
        if (value.length() > max) throw ApiException.invalid(field + " is too long (max " + max + " characters).");
        return value;
    }

    private static double number(Double value, double fallback, String field, double min, double max) {
        double v = value == null ? fallback : value;
        if (Double.isNaN(v) || v < min || v > max) {
            throw ApiException.invalid(field + " must be a number from " + fmt(min) + " to " + fmt(max) + ".");
        }
        return v;
    }

    private static String fmt(double d) {
        return d == (long) d ? Long.toString((long) d) : Double.toString(d);
    }
}
