package com.socialstories.server;

import java.time.Instant;

/**
 * A person with an account in the app. Saved in data/users.json.
 * Mutable, and only changed inside {@link UserStore}'s synchronized methods.
 */
public class User {

    public String id;
    public String email;
    public String name;
    public String passwordHash;
    public Instant createdAt;

    /** Subscription granted by the admin. {@code adminUntil} null = no end date. */
    public boolean adminGranted;
    public Instant adminUntil;

    /** Subscription bought through Google Play (checked with Google by the server). */
    public String googlePurchaseToken;
    public String googleProductId;
    public Instant googleUntil;
    public Instant googleCheckedAt;

    public boolean adminActive(Instant now) {
        return adminGranted && (adminUntil == null || now.isBefore(adminUntil));
    }

    public boolean googleActive(Instant now) {
        return googleUntil != null && now.isBefore(googleUntil);
    }

    public boolean subscribed(Instant now) {
        return adminActive(now) || googleActive(now);
    }

    /** What the app and the admin app see. Never includes the password hash. */
    public record View(String id, String email, String name, Instant createdAt, Subscription subscription) {}

    /**
     * {@code until} null with {@code active} true means no end date.
     * {@code source} is "admin", "google_play" or null.
     */
    public record Subscription(boolean active, String source, Instant until,
                               boolean adminGranted, Instant adminUntil, Instant googleUntil) {}

    public View view(Instant now) {
        String source = adminActive(now) ? "admin" : googleActive(now) ? "google_play" : null;
        Instant until = null;
        if (adminActive(now) && adminUntil == null) {
            until = null; // no end date
        } else {
            if (adminActive(now)) until = adminUntil;
            if (googleActive(now) && (until == null || googleUntil.isAfter(until))) until = googleUntil;
        }
        return new View(id, email, name, createdAt,
                new Subscription(subscribed(now), source, until, adminGranted, adminUntil, googleUntil));
    }
}
