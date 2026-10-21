package com.socialstories.server;

import java.time.Instant;

/**
 * A change a subscriber sent for review. Saved in data/submissions.json.
 * Mutable, and only changed inside {@link SubmissionStore}'s synchronized methods.
 */
public class Submission {

    public static final String NEW_STORY = "new_story";
    public static final String EDIT_STORY = "edit_story";
    public static final String EDIT_QUESTIONS = "edit_questions";

    public static final String PENDING = "pending";
    public static final String APPROVED = "approved";
    public static final String REJECTED = "rejected";
    public static final String WITHDRAWN = "withdrawn";

    public String id;
    /** {@link #NEW_STORY}, {@link #EDIT_STORY} or {@link #EDIT_QUESTIONS}. */
    public String type;
    public String status;

    /** The story being changed (for a new story: its id once approved). */
    public String storyId;

    /** The full story as it would look after approval. */
    public Story proposed;

    /** The published story when this was sent (null for a new story), so the reviewer can compare. */
    public Story base;

    public String userId;
    public String userEmail;
    public String userName;

    public Instant createdAt;
    public Instant reviewedAt;
    public String reviewNote;
}
