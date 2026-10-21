package com.socialstories.server;

import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.Signature;
import java.security.spec.PKCS8EncodedKeySpec;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/**
 * Checks Google Play subscription purchases with the Google Play Developer API
 * (purchases.subscriptionsv2.get), using a service account.
 *
 * <p>Set up: in Google Play Console create the subscription product, then a
 * service account with access to "View financial data" and point
 * {@code stories.google-play.service-account-file} (GOOGLE_PLAY_SERVICE_ACCOUNT)
 * at its JSON key file. Without it, Play purchases can't be verified and
 * only admin-granted subscriptions work.
 */
@Component
public class GooglePlay {

    /** What Google says about a purchase. {@code accountId} is the app user id set at purchase time. */
    public record Purchase(String productId, Instant expiresAt, boolean active, String accountId) {}

    private static final Logger log = LoggerFactory.getLogger(GooglePlay.class);
    private static final String SCOPE = "https://www.googleapis.com/auth/androidpublisher";

    private final StoriesProperties.GooglePlay config;
    private final JsonMapper json;
    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();
    private String accessToken;
    private Instant accessTokenExpires = Instant.EPOCH;

    public GooglePlay(StoriesProperties properties, JsonMapper json) {
        this.config = properties.googlePlayOrDefault();
        this.json = json;
    }

    public boolean configured() {
        return config.serviceAccountFile() != null && !config.serviceAccountFile().isBlank();
    }

    public String packageName() {
        return config.packageName();
    }

    public Purchase verify(String productId, String purchaseToken) {
        if (!configured()) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE,
                    "Google Play subscriptions are not set up on the server yet. Ask the admin to turn on your subscription.");
        }
        try {
            String url = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/"
                    + enc(config.packageName()) + "/purchases/subscriptionsv2/tokens/" + enc(purchaseToken);
            HttpRequest request = HttpRequest.newBuilder(URI.create(url))
                    .header("Authorization", "Bearer " + accessToken())
                    .timeout(Duration.ofSeconds(20))
                    .GET().build();
            HttpResponse<String> response = http.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() == 404 || response.statusCode() == 410 || response.statusCode() == 400) {
                throw ApiException.invalid("Google Play does not know this purchase.");
            }
            if (response.statusCode() != 200) {
                log.warn("Google Play answered {}: {}", response.statusCode(), response.body());
                throw new ApiException(HttpStatus.BAD_GATEWAY, "Could not check the purchase with Google Play. Please try again later.");
            }
            JsonNode body = json.readTree(response.body());
            String state = body.path("subscriptionState").asString("");
            boolean active = state.equals("SUBSCRIPTION_STATE_ACTIVE") || state.equals("SUBSCRIPTION_STATE_IN_GRACE_PERIOD");

            Instant expires = null;
            String product = productId;
            for (JsonNode item : body.path("lineItems")) {
                if (productId != null && !productId.equals(item.path("productId").asString(""))) continue;
                Instant e = Instant.parse(item.path("expiryTime").asString());
                if (expires == null || e.isAfter(expires)) {
                    expires = e;
                    product = item.path("productId").asString(productId);
                }
            }
            String accountId = body.path("externalAccountIdentifiers").path("obfuscatedExternalAccountId").asString(null);
            return new Purchase(product, expires, active && expires != null, accountId);
        } catch (IOException e) {
            throw new ApiException(HttpStatus.BAD_GATEWAY, "Could not reach Google Play. Please try again later.");
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new ApiException(HttpStatus.BAD_GATEWAY, "Could not reach Google Play. Please try again later.");
        }
    }

    /** OAuth access token for the service account (JWT bearer grant), cached until shortly before it expires. */
    private synchronized String accessToken() throws IOException, InterruptedException {
        if (accessToken != null && Instant.now().isBefore(accessTokenExpires)) return accessToken;

        JsonNode key = json.readTree(Files.readString(Path.of(config.serviceAccountFile())));
        String email = key.path("client_email").asString();
        String tokenUri = key.path("token_uri").asString("https://oauth2.googleapis.com/token");
        long now = Instant.now().getEpochSecond();
        String header = b64url(json.writeValueAsBytes(Map.of("alg", "RS256", "typ", "JWT")));
        String claims = b64url(json.writeValueAsBytes(Map.of(
                "iss", email, "scope", SCOPE, "aud", tokenUri, "iat", now, "exp", now + 3600)));
        String unsigned = header + "." + claims;
        String jwt = unsigned + "." + b64url(sign(unsigned, key.path("private_key").asString()));

        HttpRequest request = HttpRequest.newBuilder(URI.create(tokenUri))
                .header("Content-Type", "application/x-www-form-urlencoded")
                .timeout(Duration.ofSeconds(20))
                .POST(HttpRequest.BodyPublishers.ofString(
                        "grant_type=" + enc("urn:ietf:params:oauth:grant-type:jwt-bearer") + "&assertion=" + enc(jwt)))
                .build();
        HttpResponse<String> response = http.send(request, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() != 200) {
            log.warn("Google sign-in for the service account failed ({}): {}", response.statusCode(), response.body());
            throw new ApiException(HttpStatus.BAD_GATEWAY, "The server could not sign in to Google Play.");
        }
        JsonNode body = json.readTree(response.body());
        accessToken = body.path("access_token").asString();
        accessTokenExpires = Instant.now().plusSeconds(body.path("expires_in").asLong(3600) - 300);
        return accessToken;
    }

    private static byte[] sign(String data, String pem) {
        try {
            String base64 = pem.replaceAll("-----[A-Z ]+-----", "").replaceAll("\\s", "");
            PrivateKey key = KeyFactory.getInstance("RSA")
                    .generatePrivate(new PKCS8EncodedKeySpec(Base64.getDecoder().decode(base64)));
            Signature signature = Signature.getInstance("SHA256withRSA");
            signature.initSign(key);
            signature.update(data.getBytes(StandardCharsets.UTF_8));
            return signature.sign();
        } catch (Exception e) {
            throw new IllegalStateException("The Google service account key could not be read.", e);
        }
    }

    private static String b64url(byte[] bytes) {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private static String enc(String s) {
        return URLEncoder.encode(s, StandardCharsets.UTF_8);
    }
}
