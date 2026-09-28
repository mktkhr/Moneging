import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.androidMultiplatformLibrary)
    alias(libs.plugins.detekt)
    alias(libs.plugins.ktlintGradle)
}

kotlin {
    compilerOptions {
        allWarningsAsErrors = true
    }

    listOf(
        iosArm64(),
        iosSimulatorArm64(),
    ).forEach { iosTarget ->
        iosTarget.binaries.framework {
            baseName = "SharedLogic"
            isStatic = true
        }
    }

    android {
        namespace = "io.github.mktkhr.moneging.sharedLogic"
        compileSdk =
            libs.versions.android.compileSdk
                .get()
                .toInt()
        minSdk =
            libs.versions.android.minSdk
                .get()
                .toInt()

        compilerOptions {
            jvmTarget = JvmTarget.JVM_11
        }
        androidResources {
            enable = true
        }
        lint {
            // Same policy as androidApp: every check on, warnings fail.
            checkAllWarnings = true
            lintConfig = file("${rootProject.projectDir}/../../quality/kotlin/android-lint.xml")
            warningsAsErrors = true
            abortOnError = true
            checkTestSources = true
        }
        withHostTest {
            isIncludeAndroidResources = true
        }
    }

    sourceSets {
        commonMain.dependencies {
            // put your Multiplatform dependencies here
        }
        commonTest.dependencies {
            implementation(libs.kotlin.test)
        }
    }
}

detekt {
    allRules = true
    buildUponDefaultConfig = false
    config.setFrom(files("${rootProject.projectDir}/../../quality/kotlin/detekt.yml"))
    // detekt-gradle-plugin 1.23.8 does not generate a type-resolution task
    // for the shared commonTest/iosTest KMP source sets (only per-target
    // Main/Test and Android host/device test variants get one). Point the
    // plain, non-type-resolution `detekt` task at every source directory so
    // those two are still linted under the same policy.
    source.setFrom(
        "src/commonMain/kotlin",
        "src/commonTest/kotlin",
        "src/androidMain/kotlin",
        "src/androidHostTest/kotlin",
        "src/iosMain/kotlin",
        "src/iosTest/kotlin",
    )
}

tasks.withType<io.gitlab.arturbosch.detekt.Detekt>().configureEach {
    // See sharedUI/build.gradle.kts: a relative "**/build/**" glob does not
    // match generated source roots that already live under build/, so
    // filter by absolute path instead.
    exclude { it.file.path.contains("/build/") }
}

tasks.named("check") {
    // detekt-gradle-plugin only wires the plain `detekt` task into `check`
    // by default; the per-source-set, type-resolution-requiring tasks it
    // generates for Kotlin Multiplatform (detektMetadataMain,
    // detektAndroidMain, detektIosArm64Main, ...) are opt-in. Depend on
    // every Detekt-type task explicitly so `./gradlew build`/`check` cannot
    // silently skip the deeper, type-aware analysis.
    dependsOn(tasks.withType<io.gitlab.arturbosch.detekt.Detekt>())
}

ktlint {
    version.set("1.8.0")
    ignoreFailures.set(false)
    filter {
        // See the detekt exclusion above: generated source roots live under
        // build/ and a relative glob does not match them. sharedLogic has no
        // generated sources today, but this keeps every module configured
        // identically.
        exclude { it.file.path.contains("/build/") }
    }
}
