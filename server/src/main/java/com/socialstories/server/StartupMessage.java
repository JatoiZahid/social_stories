package com.socialstories.server;

import java.net.Inet4Address;
import java.net.NetworkInterface;
import java.util.Collections;

import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

/** Prints the admin page address, the token and the address the app should use. */
@Component
public class StartupMessage {

    private final Environment env;
    private final AdminToken token;
    private final StoryStore store;
    private final StoriesProperties properties;

    public StartupMessage(Environment env, AdminToken token, StoryStore store, StoriesProperties properties) {
        this.env = env;
        this.token = token;
        this.store = store;
        this.properties = properties;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void print() {
        String port = env.getProperty("local.server.port", env.getProperty("server.port", "8080"));
        StringBuilder out = new StringBuilder()
                .append("\n\nSocial Stories server is running (")
                .append(store.document().stories().size()).append(" stories).\n\n")
                .append("  Admin page:   http://localhost:").append(port).append('\n')
                .append("  Admin token:  ").append(token.value()).append('\n')
                .append("  Data folder:  ").append(properties.dataPath().toAbsolutePath().normalize()).append("\n\n")
                .append("  App on the Android emulator uses:  http://10.0.2.2:").append(port).append('\n');
        try {
            for (NetworkInterface ni : Collections.list(NetworkInterface.getNetworkInterfaces())) {
                if (!ni.isUp() || ni.isLoopback() || ni.isVirtual()) continue;
                for (var address : Collections.list(ni.getInetAddresses())) {
                    if (address instanceof Inet4Address && !address.isLinkLocalAddress()) {
                        out.append("  App on a phone on this Wi-Fi uses:  http://")
                                .append(address.getHostAddress()).append(':').append(port).append('\n');
                    }
                }
            }
        } catch (Exception ignored) {
            // The addresses are only a hint.
        }
        out.append("\nPress Ctrl+C to stop.\n");
        System.out.println(out);
    }
}
