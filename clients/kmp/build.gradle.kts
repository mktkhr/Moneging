plugins {
    // this is necessary to avoid the plugins to be loaded multiple times
    // in each subproject's classloader
    alias(libs.plugins.androidApplication) apply false
    alias(libs.plugins.androidMultiplatformLibrary) apply false
    alias(libs.plugins.composeMultiplatform) apply false
    alias(libs.plugins.composeCompiler) apply false
    alias(libs.plugins.detekt) apply false
    alias(libs.plugins.kotlinMultiplatform) apply false
    alias(libs.plugins.ktlintGradle) apply false
    // The quality policy for this project's own build scripts
    // (build.gradle.kts, settings.gradle.kts): ktlint over *.kts.
    id("moneging.quality")
}

// build-logic is an included build, so its own checks are not part of this
// build's task graph unless wired in explicitly.
val buildLogic = gradle.includedBuild("build-logic")
tasks.named("ktlintCheck") { dependsOn(buildLogic.task(":ktlintCheck")) }
tasks.named("ktlintFormat") { dependsOn(buildLogic.task(":ktlintFormat")) }
tasks.named("detektAll") { dependsOn(buildLogic.task(":detektAll")) }
