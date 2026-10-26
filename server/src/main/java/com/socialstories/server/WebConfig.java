package com.socialstories.server;

import java.nio.file.Path;
import java.time.Duration;

import org.springframework.context.annotation.Configuration;
import org.springframework.http.CacheControl;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/** Checks API access, serves the picture files and lets browsers on other origins call the API. */
@Configuration
public class WebConfig implements WebMvcConfigurer {

    private final ImageLibrary images;
    private final AccessCheck accessCheck;

    public WebConfig(ImageLibrary images, AccessCheck accessCheck) {
        this.images = images;
        this.accessCheck = accessCheck;
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(accessCheck).addPathPatterns("/api/**");
    }

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        registry.addResourceHandler("/uploads/**")
                .addResourceLocations(folder(images.uploadsDir()))
                .setCacheControl(CacheControl.maxAge(Duration.ofDays(365)).cachePublic()); // names are unique
        registry.addResourceHandler("/assets/images/stories/**")
                .addResourceLocations(folder(images.bundledDir()))
                .setCacheControl(CacheControl.maxAge(Duration.ofHours(1)).cachePublic());
        registry.addResourceHandler("/assets/images/story_scenes/**")
                .addResourceLocations(folder(images.scenesDir()))
                .setCacheControl(CacheControl.maxAge(Duration.ofHours(1)).cachePublic());
        registry.addResourceHandler("/assets/animations/spritesheets/**")
                .addResourceLocations(folder(images.spritesDir()))
                .setCacheControl(CacheControl.maxAge(Duration.ofHours(1)).cachePublic());
    }

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/**")
                .allowedOrigins("*")
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                .allowedHeaders("authorization", "content-type");
    }

    private static String folder(Path dir) {
        String uri = dir.toAbsolutePath().normalize().toUri().toString();
        return uri.endsWith("/") ? uri : uri + "/";
    }
}
