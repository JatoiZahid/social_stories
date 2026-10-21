package com.socialstories.server;

import java.nio.file.Path;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.regex.Pattern;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import tools.jackson.databind.json.JsonMapper;

/**
 * Accounts and login sessions, saved in data/users.json.
 * Session tokens are stored only as SHA-256 hashes.
 */
@Component
public class UserStore {

    static final Duration SESSION_LIFETIME = Duration.ofDays(180);
    private static final Pattern EMAIL = Pattern.compile("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$");
    private static final int MAX_FAILED_LOGINS = 10;
    private static final Duration LOGIN_WINDOW = Duration.ofMinutes(15);

    public static class Session {
        public String tokenHash;
        public String userId;
        public Instant createdAt;
    }

    public static class Data {
        public List<User> users = new ArrayList<>();
        public List<Session> sessions = new ArrayList<>();
    }

    private record Failures(int count, Instant since) {}

    private final Path file;
    private final JsonMapper json;
    private final Data data;
    private final Map<String, Failures> failures = new HashMap<>();

    public UserStore(StoriesProperties properties, JsonMapper json) {
        this.file = properties.dataPath().resolve("users.json");
        this.json = json;
        Data loaded = JsonFiles.read(json, file, Data.class);
        this.data = loaded != null ? loaded : new Data();
    }

    /** A logged-in user plus the token the app keeps. */
    public record Login(User user, String token) {}

    public synchronized Login register(String email, String password, String name) {
        String cleanEmail = normalizeEmail(email);
        if (!EMAIL.matcher(cleanEmail).matches() || cleanEmail.length() > 200) {
            throw ApiException.invalid("Please enter a valid email address.");
        }
        if (password == null || password.length() < 8 || password.length() > 200) {
            throw ApiException.invalid("The password needs at least 8 characters.");
        }
        if (findByEmail(cleanEmail).isPresent()) {
            throw new ApiException(HttpStatus.CONFLICT, "An account with this email already exists. Please sign in.");
        }
        User user = new User();
        user.id = Passwords.newId();
        user.email = cleanEmail;
        user.name = name == null ? "" : name.trim().substring(0, Math.min(name.trim().length(), 80));
        user.passwordHash = Passwords.hash(password);
        user.createdAt = Instant.now();
        data.users.add(user);
        return new Login(user, newSession(user));
    }

    public synchronized Login login(String email, String password) {
        String cleanEmail = normalizeEmail(email);
        Instant now = Instant.now();
        Failures f = failures.get(cleanEmail);
        if (f != null && f.since().plus(LOGIN_WINDOW).isAfter(now) && f.count() >= MAX_FAILED_LOGINS) {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "Too many attempts. Please wait 15 minutes and try again.");
        }
        Optional<User> user = findByEmail(cleanEmail);
        if (user.isEmpty() || !Passwords.matches(password, user.get().passwordHash)) {
            boolean fresh = f == null || f.since().plus(LOGIN_WINDOW).isBefore(now);
            failures.put(cleanEmail, fresh ? new Failures(1, now) : new Failures(f.count() + 1, f.since()));
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Wrong email or password.");
        }
        failures.remove(cleanEmail);
        return new Login(user.get(), newSession(user.get()));
    }

    public synchronized void logout(String token) {
        String hash = Passwords.sha256(token);
        if (data.sessions.removeIf(s -> s.tokenHash.equals(hash))) save();
    }

    /** The user a session token belongs to, if it is still valid. */
    public synchronized Optional<User> userForToken(String token) {
        String hash = Passwords.sha256(token);
        Instant oldest = Instant.now().minus(SESSION_LIFETIME);
        for (Session s : data.sessions) {
            if (s.tokenHash.equals(hash) && s.createdAt.isAfter(oldest)) return byId(s.userId);
        }
        return Optional.empty();
    }

    public synchronized Optional<User> byId(String id) {
        return data.users.stream().filter(u -> u.id.equals(id)).findFirst();
    }

    public synchronized List<User> all() {
        return data.users.stream().sorted(Comparator.comparing((User u) -> u.createdAt).reversed()).toList();
    }

    /** Turns the admin-granted subscription on (until a date, or with no end) or off. */
    public synchronized User setAdminSubscription(String id, boolean granted, Instant until) {
        User user = byId(id).orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "No user with id \"" + id + "\"."));
        user.adminGranted = granted;
        user.adminUntil = granted ? until : null;
        save();
        return user;
    }

    /** Records a Google Play subscription the server has checked with Google. */
    public synchronized User setGooglePlay(String id, String purchaseToken, String productId, Instant until) {
        User user = byId(id).orElseThrow();
        for (User other : data.users) {
            if (!other.id.equals(id) && purchaseToken.equals(other.googlePurchaseToken)) {
                throw new ApiException(HttpStatus.CONFLICT, "This Google Play subscription belongs to another account.");
            }
        }
        user.googlePurchaseToken = purchaseToken;
        user.googleProductId = productId;
        user.googleUntil = until;
        user.googleCheckedAt = Instant.now();
        save();
        return user;
    }

    private String newSession(User user) {
        String token = Passwords.newToken();
        Session session = new Session();
        session.tokenHash = Passwords.sha256(token);
        session.userId = user.id;
        session.createdAt = Instant.now();
        Instant oldest = Instant.now().minus(SESSION_LIFETIME);
        data.sessions.removeIf(s -> s.createdAt.isBefore(oldest));
        data.sessions.add(session);
        save();
        return token;
    }

    private Optional<User> findByEmail(String email) {
        return data.users.stream().filter(u -> u.email.equals(email)).findFirst();
    }

    private static String normalizeEmail(String email) {
        return email == null ? "" : email.trim().toLowerCase(Locale.ROOT);
    }

    private void save() {
        JsonFiles.write(json, file, data);
    }
}
