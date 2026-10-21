package com.socialstories.server;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.format.DateTimeParseException;
import java.util.List;
import java.util.Map;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Reviewing submissions and managing subscribers (used by the admin app). */
@RestController
@RequestMapping("/api/admin")
@Access(Access.Level.ADMIN)
public class AdminController {

    private final SubmissionStore submissions;
    private final UserStore users;

    public AdminController(SubmissionStore submissions, UserStore users) {
        this.submissions = submissions;
        this.users = users;
    }

    public record ReviewRequest(String note) {}

    /** {@code until}: a date like 2027-01-31 (last day included), or null for no end date. */
    public record SubscriptionRequest(boolean active, String until) {}

    public record UserRow(String id, String email, String name, Instant createdAt,
                          User.Subscription subscription, long pendingSubmissions) {}

    /** Numbers for the admin app's home screen. */
    @GetMapping("/summary")
    public Map<String, Long> summary() {
        Instant now = Instant.now();
        List<User> all = users.all();
        return Map.of(
                "pending", (long) submissions.list(Submission.PENDING).size(),
                "users", (long) all.size(),
                "subscribers", all.stream().filter(u -> u.subscribed(now)).count());
    }

    /** {@code status}: pending (default), approved, rejected, withdrawn or all. */
    @GetMapping("/submissions")
    public List<SubmissionView> submissions(@RequestParam(defaultValue = "pending") String status) {
        return submissions.list("all".equals(status) ? null : status).stream()
                .map(s -> SubmissionView.of(s, submissions.outdated(s))).toList();
    }

    @GetMapping("/submissions/{id}")
    public SubmissionView submission(@PathVariable String id) {
        Submission s = submissions.byId(id);
        return SubmissionView.of(s, submissions.outdated(s));
    }

    @PostMapping("/submissions/{id}/approve")
    public SubmissionView approve(@PathVariable String id, @RequestBody(required = false) ReviewRequest body) {
        return SubmissionView.of(submissions.approve(id, body == null ? null : body.note()), false);
    }

    @PostMapping("/submissions/{id}/reject")
    public SubmissionView reject(@PathVariable String id, @RequestBody(required = false) ReviewRequest body) {
        return SubmissionView.of(submissions.reject(id, body == null ? null : body.note()), false);
    }

    @GetMapping("/users")
    public List<UserRow> users() {
        return users.all().stream().map(this::row).toList();
    }

    /** Turns a user's admin-granted subscription on or off. */
    @PutMapping("/users/{id}/subscription")
    public UserRow subscription(@PathVariable String id, @RequestBody SubscriptionRequest body) {
        Instant until = null;
        if (body.active() && body.until() != null && !body.until().isBlank()) {
            try {
                // Valid through the whole of the given day (UTC).
                until = LocalDate.parse(body.until().trim()).plusDays(1).atStartOfDay().toInstant(ZoneOffset.UTC);
            } catch (DateTimeParseException e) {
                throw ApiException.invalid("The end date must look like 2027-01-31.");
            }
            if (until.isBefore(Instant.now())) throw ApiException.invalid("The end date is in the past.");
        }
        return row(users.setAdminSubscription(id, body.active(), until));
    }

    private UserRow row(User user) {
        User.View v = user.view(Instant.now());
        return new UserRow(v.id(), v.email(), v.name(), v.createdAt(), v.subscription(), submissions.pendingCount(user.id));
    }
}
