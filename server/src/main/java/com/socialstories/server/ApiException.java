package com.socialstories.server;

import org.springframework.http.HttpStatus;

/** An error the API reports to the caller as {@code {"error": message}}. */
public class ApiException extends RuntimeException {

    private final HttpStatus status;

    public ApiException(HttpStatus status, String message) {
        super(message);
        this.status = status;
    }

    public HttpStatus status() {
        return status;
    }

    public static ApiException invalid(String message) {
        return new ApiException(HttpStatus.BAD_REQUEST, message);
    }

    public static ApiException notFound(String id) {
        return new ApiException(HttpStatus.NOT_FOUND, "No story with id \"" + id + "\".");
    }
}
