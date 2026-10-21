package com.socialstories.server;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Who may call an API method. Without it, GET is public and anything else
 * is admin-only, so a new endpoint is never accidentally open.
 */
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.METHOD, ElementType.TYPE})
public @interface Access {

    Level value();

    enum Level {
        /** Anyone. */
        PUBLIC,
        /** A signed-in user. */
        USER,
        /** A signed-in user with an active subscription (or the admin). */
        SUBSCRIBER,
        /** The admin token (web admin page and admin app). */
        ADMIN
    }
}
