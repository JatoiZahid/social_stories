package com.socialstories.server;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Reads {@code Authorization: Bearer <token>} and records who is calling.
 * The admin token makes the caller the admin; a session token makes them
 * that user. Whether they may call an endpoint is decided by {@link AccessCheck}.
 */
@Component
public class AuthFilter extends OncePerRequestFilter {

    private final byte[] adminToken;
    private final UserStore users;

    public AuthFilter(AdminToken adminToken, UserStore users) {
        this.adminToken = adminToken.value().getBytes(StandardCharsets.UTF_8);
        this.users = users;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        String path = request.getRequestURI().substring(request.getContextPath().length());
        if (path.startsWith("/api/")) {
            response.setHeader("Cache-Control", "no-cache"); // the app should always get the latest data
            String header = request.getHeader("Authorization");
            if (header != null && header.startsWith("Bearer ")) {
                String token = header.substring(7).trim();
                // Constant-time compare, so the admin token can't be guessed by timing.
                if (MessageDigest.isEqual(token.getBytes(StandardCharsets.UTF_8), adminToken)) {
                    request.setAttribute(Caller.ATTRIBUTE, new Caller(true, null, token));
                } else if (!token.isEmpty()) {
                    users.userForToken(token)
                            .ifPresent(user -> request.setAttribute(Caller.ATTRIBUTE, new Caller(false, user, token)));
                }
            }
        }
        chain.doFilter(request, response);
    }
}
