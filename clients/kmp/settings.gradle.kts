rootProject.name = "Moneging"

pluginManagement {
    // The convention plugin (id "moneging.quality") that owns every
    // strictness switch; each module only applies it.
    includeBuild("build-logic")
    repositories {
        google {
            mavenContent {
                includeGroupAndSubgroups("androidx")
                includeGroupAndSubgroups("com.android")
                includeGroupAndSubgroups("com.google")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    // Lets Gradle auto-provision JDKs it doesn't find locally - required for
    // `./gradlew updateDaemonJvm` to resolve a concrete JDK build, and useful
    // generally so a toolchain-based build works without every developer
    // having pre-installed the exact JDK clients/kmp/gradle/gradle-daemon-jvm.properties names.
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}

dependencyResolutionManagement {
    repositories {
        google {
            mavenContent {
                includeGroupAndSubgroups("androidx")
                includeGroupAndSubgroups("com.android")
                includeGroupAndSubgroups("com.google")
            }
        }
        mavenCentral()
    }
}

include(":androidApp")
include(":sharedLogic")
include(":sharedUI")
