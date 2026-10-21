package com.socialstories.server;

import java.time.Duration;
import java.time.Instant;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/**
 * Whether a user's subscription is active. Google Play subscriptions renew
 * on Google's side, so when the saved expiry date has passed, the server
 * asks Google again (at most once an hour per user).
 */
@Component
public class Subscriptions {

    private static final Logger log = LoggerFactory.getLogger(Subscriptions.class);
    private static final Duration RECHECK_AFTER = Duration.ofHours(1);

    private final UserStore users;
    private final GooglePlay googlePlay;

    public Subscriptions(UserStore users, GooglePlay googlePlay) {
        this.users = users;
        this.googlePlay = googlePlay;
    }

    public boolean active(User user) {
        return refresh(user).subscribed(Instant.now());
    }

    /** The user, with their Google Play status re-checked if it may have renewed. */
    public User refresh(User user) {
        Instant now = Instant.now();
        boolean worthChecking = user.googlePurchaseToken != null && !user.googleActive(now)
                && (user.googleCheckedAt == null || user.googleCheckedAt.plus(RECHECK_AFTER).isBefore(now))
                && googlePlay.configured();
        if (!worthChecking) return user;
        try {
            GooglePlay.Purchase purchase = googlePlay.verify(user.googleProductId, user.googlePurchaseToken);
            return users.setGooglePlay(user.id, user.googlePurchaseToken, purchase.productId(),
                    purchase.active() ? purchase.expiresAt() : null);
        } catch (ApiException e) {
            log.info("Could not re-check the Google Play subscription of {}: {}", user.email, e.getMessage());
            return user;
        }
    }

    /** Checks a purchase the app just made and attaches it to the user. */
    public User attachGooglePlay(User user, String productId, String purchaseToken) {
        if (purchaseToken == null || purchaseToken.isBlank()) throw ApiException.invalid("The purchase token is missing.");
        GooglePlay.Purchase purchase = googlePlay.verify(productId, purchaseToken);
        if (purchase.accountId() != null && !purchase.accountId().equals(user.id)) {
            throw new ApiException(HttpStatus.CONFLICT, "This Google Play subscription belongs to another account.");
        }
        if (!purchase.active()) throw ApiException.invalid("This Google Play subscription is not active.");
        return users.setGooglePlay(user.id, purchaseToken, purchase.productId(), purchase.expiresAt());
    }
}
