package com.socialstories.server;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

/**
 * Backend for Social Stories: serves the story list to the app and an admin
 * page (src/main/resources/static/index.html) to add and edit stories.
 */
@SpringBootApplication
@ConfigurationPropertiesScan
public class SocialStoriesServer {

    public static void main(String[] args) {
        SpringApplication.run(SocialStoriesServer.class, args);
    }
}
