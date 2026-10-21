package com.socialstories.server;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;

/** Enforces {@link Access} on every API method before it runs. */
@Component
public class AccessCheck implements HandlerInterceptor {

    private final Subscriptions subscriptions;

    public AccessCheck(Subscriptions subscriptions) {
        this.subscriptions = subscriptions;
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        if (!(handler instanceof HandlerMethod method)) return true; // static files
        Access access = method.getMethodAnnotation(Access.class);
        if (access == null) access = method.getBeanType().getAnnotation(Access.class);
        Access.Level level = access != null ? access.value()
                : "GET".equals(request.getMethod()) ? Access.Level.PUBLIC : Access.Level.ADMIN;

        Caller caller = Caller.of(request);
        switch (level) {
            case PUBLIC -> { }
            case USER -> caller.requireUser();
            case SUBSCRIBER -> {
                if (caller.admin()) return true;
                if (!subscriptions.active(caller.requireUser())) {
                    throw new ApiException(HttpStatus.FORBIDDEN, "You need an active subscription to do this.");
                }
            }
            case ADMIN -> {
                if (!caller.admin()) throw new ApiException(HttpStatus.UNAUTHORIZED, "Wrong or missing admin token.");
            }
        }
        return true;
    }
}
