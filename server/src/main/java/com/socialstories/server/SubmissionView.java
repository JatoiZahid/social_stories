package com.socialstories.server;

import java.time.Instant;

/**
 * A submission as the apps see it. {@code outdated} (admin only) is true
 * when the published story changed after this was sent.
 */
public record SubmissionView(
        String id,
        String type,
        String status,
        String storyId,
        String title,
        Story proposed,
        Story base,
        Submitter submittedBy,
        Instant createdAt,
        Instant reviewedAt,
        String reviewNote,
        boolean outdated) {

    public record Submitter(String id, String email, String name) {}

    static SubmissionView of(Submission s, boolean outdated) {
        return new SubmissionView(s.id, s.type, s.status, s.storyId, s.proposed.title(), s.proposed, s.base,
                new Submitter(s.userId, s.userEmail, s.userName), s.createdAt, s.reviewedAt, s.reviewNote, outdated);
    }
}
