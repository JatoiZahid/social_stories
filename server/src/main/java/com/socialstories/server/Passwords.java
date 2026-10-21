package com.socialstories.server;

import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.HexFormat;

import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;

/** Password hashing (PBKDF2-SHA256) and random tokens, using only the JDK. */
final class Passwords {

    private static final SecureRandom RANDOM = new SecureRandom();
    private static final int ITERATIONS = 210_000;

    private Passwords() {}

    /** Returns {@code pbkdf2$<iterations>$<salt>$<hash>}. */
    static String hash(String password) {
        byte[] salt = new byte[16];
        RANDOM.nextBytes(salt);
        return "pbkdf2$" + ITERATIONS + "$" + b64(salt) + "$" + b64(pbkdf2(password, salt, ITERATIONS));
    }

    static boolean matches(String password, String stored) {
        if (password == null || stored == null) return false;
        String[] parts = stored.split("\\$");
        if (parts.length != 4 || !parts[0].equals("pbkdf2")) return false;
        byte[] salt = Base64.getDecoder().decode(parts[2]);
        byte[] expected = Base64.getDecoder().decode(parts[3]);
        return MessageDigest.isEqual(expected, pbkdf2(password, salt, Integer.parseInt(parts[1])));
    }

    /** A random token for a login session (sent to the app once, stored only as a hash). */
    static String newToken() {
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    static String newId() {
        byte[] bytes = new byte[8];
        RANDOM.nextBytes(bytes);
        return HexFormat.of().formatHex(bytes);
    }

    static String sha256(String text) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(text.getBytes(java.nio.charset.StandardCharsets.UTF_8)));
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException(e);
        }
    }

    private static byte[] pbkdf2(String password, byte[] salt, int iterations) {
        try {
            var spec = new PBEKeySpec(password.toCharArray(), salt, iterations, 256);
            return SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).getEncoded();
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException(e);
        }
    }

    private static String b64(byte[] bytes) {
        return Base64.getEncoder().encodeToString(bytes);
    }
}
