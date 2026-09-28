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

// The executable acceptance criteria of PRODUCT.md §7 for the shared logic
// (AC-B), kept outside the product tree in acceptance/shared and run against
// :sharedLogic by `make acceptance-shared`. Only that target asks for the
// module (-Pmoneging.acceptance): acceptance tests are written before the code
// they exercise, so they may not compile yet, and every other build (make
// verify's ktlint/detekt/Android Lint/tests, the iOS framework) must not
// compile them.
if (providers.gradleProperty("moneging.acceptance").isPresent) {
    include(":acceptanceShared")
    project(":acceptanceShared").projectDir = file("../../acceptance/shared")
}
