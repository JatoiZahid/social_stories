package com.socialstories.server;

import java.time.Instant;
import java.util.List;

import jakarta.servlet.http.HttpServletRequest;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Accounts, subscriptions and sending changes for review (used by the app). */
@RestController
@RequestMapping("/api")
public class AccountController {

    private final UserStore users;
    private final Subscriptions subscriptions;
    private final SubmissionStore submissions;

    public AccountController(UserStore users, Subscriptions subscriptions, SubmissionStore submissions) {
        this.users = users;
        this.subscriptions = subscriptions;
        this.submissions = submissions;
    }

    public record RegisterRequest(String email, String password, String name) {}

    public record LoginRequest(String email, String password) {}

    /** {@code token} goes in {@code Authorization: Bearer <token>} from now on. */
    public record LoginResponse(String token, Me user) {}

    /** The signed-in user, plus how many of their changes are waiting for review. */
    public record Me(String id, String email, String name, Instant createdAt,
                     User.Subscription subscription, long pendingSubmissions) {}

    public record GooglePlayRequest(String productId, String purchaseToken) {}

    @PostMapping("/auth/register")
    @ResponseStatus(HttpStatus.CREATED)
    @Access(Access.Level.PUBLIC)
    public LoginResponse register(@RequestBody RegisterRequest request) {
        UserStore.Login login = users.register(request.email(), request.password(), request.name());
        return new LoginResponse(login.token(), me(login.user()));
    }

    @PostMapping("/auth/login")
    @Access(Access.Level.PUBLIC)
    public LoginResponse login(@RequestBody LoginRequest request) {
        UserStore.Login login = users.login(request.email(), request.password());
        return new LoginResponse(login.token(), me(login.user()));
    }

    @PostMapping("/auth/logout")
    @Access(Access.Level.USER)
    public ResponseEntity<Void> logout(HttpServletRequest request) {
        users.logout(Caller.of(request).token());
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/me")
    @Access(Access.Level.USER)
    public Me me(HttpServletRequest request) {
        return me(subscriptions.refresh(Caller.of(request).requireUser()));
    }

    /** The app sends a Google Play purchase here; the server checks it with Google. */
    @PostMapping("/me/google-play")
    @Access(Access.Level.USER)
    public Me googlePlay(HttpServletRequest request, @RequestBody GooglePlayRequest body) {
        User user = Caller.of(request).requireUser();
        return me(subscriptions.attachGooglePlay(user, body.productId(), body.purchaseToken()));
    }

    @GetMapping("/me/submissions")
    @Access(Access.Level.USER)
    public List<SubmissionView> mySubmissions(HttpServletRequest request) {
        return submissions.forUser(Caller.of(request).requireUser().id).stream()
                .map(s -> SubmissionView.of(s, false)).toList();
    }

    /** Takes back a change that has not been reviewed yet. */
    @DeleteMapping("/me/submissions/{id}")
    @Access(Access.Level.USER)
    public SubmissionView withdraw(HttpServletRequest request, @PathVariable String id) {
        return SubmissionView.of(submissions.withdraw(Caller.of(request).requireUser(), id), false);
    }

    /** Sends a new story, a story edit or new questions for review. */
    @PostMapping("/submissions")
    @ResponseStatus(HttpStatus.CREATED)
    @Access(Access.Level.SUBSCRIBER)
    public SubmissionView submit(HttpServletRequest request, @RequestBody SubmissionStore.Request body) {
        return SubmissionView.of(submissions.submit(Caller.of(request).requireUser(), body), false);
    }

    private Me me(User user) {
        User.View view = user.view(Instant.now());
        return new Me(view.id(), view.email(), view.name(), view.createdAt(), view.subscription(),
                submissions.pendingCount(user.id));
    }
}
