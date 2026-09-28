plugins {
    // this is necessary to avoid the plugins to be loaded multiple times
    // in each subproject's classloader
    alias(libs.plugins.androidApplication) apply false
    alias(libs.plugins.androidMultiplatformLibrary) apply false
    alias(libs.plugins.composeMultiplatform) apply false
    alias(libs.plugins.composeCompiler) apply false
    alias(libs.plugins.detekt) apply false
    alias(libs.plugins.kotlinMultiplatform) apply false
    alias(libs.plugins.ktlintGradle)
}
// Applied here too (not only `apply false`) so ktlint also checks this
// project's own build scripts (build.gradle.kts, settings.gradle.kts).
ktlint {
    version.set("1.8.0")
    ignoreFailures.set(false)
}
