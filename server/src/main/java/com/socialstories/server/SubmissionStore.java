package com.socialstories.server;

import java.nio.file.Path;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;
import java.util.Optional;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import tools.jackson.databind.json.JsonMapper;

/**
 * The review queue. Subscribers send changes here; nothing reaches the
 * published stories until the admin approves it.
 */
@Component
public class SubmissionStore {

    static final int MAX_PENDING_PER_USER = 20;

    public static class Data {
        public List<Submission> submissions = new ArrayList<>();
    }

    /** What a subscriber sends: {@code storyId} is required for edits. */
    public record Request(String type, String storyId, Story story) {}

    private final Path file;
    private final JsonMapper json;
    private final StoryStore stories;
    private final Data data;

    public SubmissionStore(StoriesProperties properties, JsonMapper json, StoryStore stories) {
        this.file = properties.dataPath().resolve("submissions.json");
        this.json = json;
        this.stories = stories;
        Data loaded = JsonFiles.read(json, file, Data.class);
        this.data = loaded != null ? loaded : new Data();
    }

    /**
     * Checks a change and puts it in the queue. Sending the same kind of edit
     * for the same story again replaces the one still waiting.
     */
    public synchronized Submission submit(User user, Request request) {
        if (request == null || request.type() == null) throw ApiException.invalid("Say what kind of change this is.");
        if (request.story() == null) throw ApiException.invalid("The change has no story in it.");

        Submission s = new Submission();
        s.type = request.type();
        switch (request.type()) {
            case Submission.NEW_STORY -> {
                s.proposed = stories.validate(request.story(), "new_story");
                s.storyId = null;
            }
            case Submission.EDIT_STORY -> {
                s.base = published(request.storyId());
                Story proposal = request.story();
                s.proposed = stories.validate(
                        new Story(s.base.id(), proposal.title(), proposal.pages(), s.base.questions()), s.base.id());
                if (sameContent(s.proposed, s.base)) throw ApiException.invalid("Nothing has changed in this story yet.");
                s.storyId = s.base.id();
            }
            case Submission.EDIT_QUESTIONS -> {
                s.base = published(request.storyId());
                s.proposed = stories.validate(
                        new Story(s.base.id(), s.base.title(), s.base.pages(), request.story().questions()), s.base.id());
                if (sameQuestions(s.proposed, s.base)) throw ApiException.invalid("The questions have not changed yet.");
                s.storyId = s.base.id();
            }
            default -> throw ApiException.invalid("Unknown kind of change: " + request.type());
        }

        Optional<Submission> waiting = s.storyId == null ? Optional.empty() : data.submissions.stream()
                .filter(o -> o.userId.equals(user.id) && o.status.equals(Submission.PENDING)
                        && o.type.equals(s.type) && s.storyId.equals(o.storyId))
                .findFirst();
        if (waiting.isPresent()) {
            Submission old = waiting.get();
            old.proposed = s.proposed;
            old.base = s.base;
            old.createdAt = Instant.now();
            save();
            return old;
        }

        long pending = data.submissions.stream()
                .filter(o -> o.userId.equals(user.id) && o.status.equals(Submission.PENDING)).count();
        if (pending >= MAX_PENDING_PER_USER) {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS,
                    "You have " + pending + " changes waiting for review. Please wait until some are reviewed.");
        }
        s.id = Passwords.newId();
        s.status = Submission.PENDING;
        s.userId = user.id;
        s.userEmail = user.email;
        s.userName = user.name;
        s.createdAt = Instant.now();
        data.submissions.add(s);
        save();
        return s;
    }

    public synchronized List<Submission> forUser(String userId) {
        return data.submissions.stream()
                .filter(s -> s.userId.equals(userId))
                .sorted(Comparator.comparing((Submission s) -> s.createdAt).reversed())
                .toList();
    }

    /** {@code status} null = all. Newest first, except pending: oldest first (review in order). */
    public synchronized List<Submission> list(String status) {
        Comparator<Submission> byDate = Comparator.comparing(s -> s.createdAt);
        return data.submissions.stream()
                .filter(s -> status == null || s.status.equals(status))
                .sorted(Submission.PENDING.equals(status) ? byDate : byDate.reversed())
                .toList();
    }

    public synchronized Submission byId(String id) {
        return data.submissions.stream().filter(s -> s.id.equals(id)).findFirst()
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "No submission with id \"" + id + "\"."));
    }

    public synchronized long pendingCount(String userId) {
        return data.submissions.stream()
                .filter(s -> s.userId.equals(userId) && s.status.equals(Submission.PENDING)).count();
    }

    /** The submitter takes back a change that has not been reviewed yet. */
    public synchronized Submission withdraw(User user, String id) {
        Submission s = byId(id);
        if (!s.userId.equals(user.id)) throw new ApiException(HttpStatus.NOT_FOUND, "No submission with id \"" + id + "\".");
        requirePending(s);
        s.status = Submission.WITHDRAWN;
        s.reviewedAt = Instant.now();
        save();
        return s;
    }

    /** Publishes the change. */
    public synchronized Submission approve(String id, String note) {
        Submission s = byId(id);
        requirePending(s);
        Story published = switch (s.type) {
            case Submission.NEW_STORY -> stories.publishNew(s.proposed);
            case Submission.EDIT_STORY -> stories.publishEdit(s.storyId, s.proposed);
            case Submission.EDIT_QUESTIONS -> stories.publishQuestions(s.storyId, s.proposed.questions());
            default -> throw ApiException.invalid("Unknown kind of change: " + s.type);
        };
        s.storyId = published.id();
        s.status = Submission.APPROVED;
        s.reviewNote = clean(note);
        s.reviewedAt = Instant.now();
        save();
        return s;
    }

    public synchronized Submission reject(String id, String note) {
        Submission s = byId(id);
        requirePending(s);
        s.status = Submission.REJECTED;
        s.reviewNote = clean(note);
        s.reviewedAt = Instant.now();
        save();
        return s;
    }

    /** True if the published story changed after this was sent (approving would overwrite that change). */
    public boolean outdated(Submission s) {
        if (s.base == null || !Submission.PENDING.equals(s.status)) return false;
        return stories.byId(s.storyId)
                .map(current -> Submission.EDIT_QUESTIONS.equals(s.type)
                        ? !sameQuestions(current, s.base)
                        : !sameContent(current, s.base))
                .orElse(true);
    }

    private Story published(String storyId) {
        if (storyId == null) throw ApiException.invalid("Say which story this change is for.");
        return stories.byId(storyId).orElseThrow(() -> ApiException.notFound(storyId));
    }

    private static void requirePending(Submission s) {
        if (!Submission.PENDING.equals(s.status)) {
            throw new ApiException(HttpStatus.CONFLICT, "This change was already " + s.status + ".");
        }
    }

    /** Title and pages, ignoring page ids. */
    static boolean sameContent(Story a, Story b) {
        if (!a.title().equals(b.title()) || a.pages().size() != b.pages().size()) return false;
        for (int i = 0; i < a.pages().size(); i++) {
            Story.Page x = a.pages().get(i), y = b.pages().get(i);
            if (!x.image().equals(y.image()) || !x.lead().equals(y.lead()) || !x.body().equals(y.body())
                    || !Objects.equals(x.focus(), y.focus())) {
                return false;
            }
        }
        return true;
    }

    /** Questions, ignoring question ids. */
    static boolean sameQuestions(Story a, Story b) {
        List<Story.Question> x = a.questionsOrEmpty(), y = b.questionsOrEmpty();
        if (x.size() != y.size()) return false;
        for (int i = 0; i < x.size(); i++) {
            if (!x.get(i).question().equals(y.get(i).question()) || !x.get(i).choices().equals(y.get(i).choices())
                    || !x.get(i).answer().equals(y.get(i).answer())) {
                return false;
            }
        }
        return true;
    }

    private static String clean(String note) {
        if (note == null || note.isBlank()) return null;
        String n = note.trim();
        return n.length() > 1000 ? n.substring(0, 1000) : n;
    }

    private void save() {
        JsonFiles.write(json, file, data);
    }
}
