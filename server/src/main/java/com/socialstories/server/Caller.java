package com.socialstories.server;

import jakarta.servlet.http.HttpServletRequest;

import org.springframework.http.HttpStatus;

/**
 * Who sent a request: the admin (admin token) and/or a signed-in user
 * (session token). Set on every request by {@link AuthFilter}.
 */
public record Caller(boolean admin, User user, String token) {

    static final String ATTRIBUTE = Caller.class.getName();
    static final Caller NOBODY = new Caller(false, null, null);

    public static Caller of(HttpServletRequest request) {
        Object caller = request.getAttribute(ATTRIBUTE);
        return caller instanceof Caller c ? c : NOBODY;
    }

    /** The signed-in user, or a 401 error. */
    public User requireUser() {
        if (user == null) throw new ApiException(HttpStatus.UNAUTHORIZED, "Please sign in.");
        return user;
    }
}
