// Included build holding the Gradle convention plugin that owns every
// strictness switch of the Kotlin toolchain (compiler warnings, detekt,
// ktlint, Android Lint). Part of the Repository Harness
// (quality/protected-paths.txt): module build scripts only apply it.
rootProject.name = "build-logic"

pluginManagement {
    repositories {
        gradlePluginPortal()
        mavenCentral()
    }
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
        gradlePluginPortal()
    }
    versionCatalogs {
        create("libs") {
            from(files("../gradle/libs.versions.toml"))
        }
    }
}
