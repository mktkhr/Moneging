plugins {
    `kotlin-dsl`
    alias(libs.plugins.detekt)
    alias(libs.plugins.ktlintGradle)
}

// Build output goes to clients/kmp/build/build-logic, not build-logic/build:
// this directory is a protected harness path, and scripts/guard/ignored-paths.sh
// rightly refuses ignored report files (*.md, *.txt) under one.
layout.buildDirectory = rootDir.resolve("../build/build-logic")

dependencies {
    // compileOnly: the plugins themselves are put on the build classpath by
    // clients/kmp/build.gradle.kts (`apply false`), so each module resolves
    // exactly one copy of them.
    compileOnly(libs.android.gradlePlugin)
    compileOnly(libs.kotlin.gradlePlugin)
    compileOnly(libs.detekt.gradlePlugin)
    compileOnly(libs.ktlint.gradlePlugin)
}

gradlePlugin {
    plugins {
        register("quality") {
            id = "moneging.quality"
            implementationClass = "io.github.mktkhr.moneging.buildlogic.QualityConventionPlugin"
        }
    }
}

kotlin {
    compilerOptions {
        allWarningsAsErrors = true
    }
}

// The convention plugin cannot apply itself, so this build holds the same
// policy for its own sources directly.
detekt {
    allRules = true
    buildUponDefaultConfig = false
    failOnSeverity = dev.detekt.gradle.extensions.FailOnSeverity.Info
    config.setFrom(files("../../../quality/kotlin/detekt.yml"))
}

ktlint {
    version = libs.versions.ktlint
    ignoreFailures = false
}

val detektAll by tasks.registering {
    description = "Runs every detekt task of this build."
    group = "verification"
    dependsOn(tasks.withType<dev.detekt.gradle.Detekt>())
}

tasks.named("check") {
    dependsOn(detektAll)
}
