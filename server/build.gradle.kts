plugins {
    java
    id("org.springframework.boot") version "4.1.1"
    id("io.spring.dependency-management") version "1.1.7"
}

group = "com.socialstories"
version = "1.0.0"

repositories {
    mavenCentral()
}

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-webmvc")
    testImplementation("org.springframework.boot:spring-boot-starter-webmvc-test")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

// Runs on any Java 17 or newer, whatever JDK builds it.
tasks.withType<JavaCompile> {
    options.release = 17
    options.compilerArgs.add("-parameters")
}

tasks.test {
    useJUnitPlatform()
}

// `gradlew bootRun` runs from this folder, so the default paths
// (data/ here, the app's assets in ../) work out of the box.
tasks.named<org.springframework.boot.gradle.tasks.run.BootRun>("bootRun") {
    workingDir = projectDir
}
