import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.androidMultiplatformLibrary)
    // SKIE turns this module's suspend functions/Flows into Swift
    // async/await and AsyncSequence for the iOS app; only sharedLogic
    // produces the exported framework, so no root apply-false wiring.
    alias(libs.plugins.skie)
    // The on-device database (PRODUCT.md §6, Durability): schema and
    // queries in src/commonMain/sqldelight, migrations applied on start.
    alias(libs.plugins.sqldelight)
    // Static-analysis policy (compiler warnings, detekt, ktlint, Android
    // Lint): clients/kmp/build-logic.
    id("moneging.quality")
}

kotlin {
    listOf(
        iosArm64(),
        iosSimulatorArm64(),
    ).forEach { iosTarget ->
        iosTarget.binaries.framework {
            baseName = "SharedLogic"
            isStatic = true
        }
        iosTarget.compilations.getByName("main").cinterops.create("sqlite3") {
            definitionFile.set(project.file("src/nativeInterop/cinterop/sqlite3.def"))
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
        withHostTest {
            isIncludeAndroidResources = true
        }
    }

    sourceSets {
        commonMain.dependencies {
            implementation(libs.koin.core)
            implementation(libs.androidx.lifecycle.viewmodel)
            implementation(libs.kotlinx.coroutines.core)
            implementation(libs.sqldelight.runtime)
            implementation(libs.sqldelight.coroutines)
            // LocalDate and YearMonth are part of the public API (domain).
            api(libs.kotlinx.datetime)
        }
        androidMain.dependencies {
            implementation(libs.androidx.core.ktx)
            implementation(libs.sqldelight.androidDriver)
            // The in-memory store (LocalStore.inMemory) on the JVM, where
            // the Android host tests run without an Android framework. The
            // app itself never opens it; androidApp leaves it out of the APK.
            implementation(libs.sqldelight.sqliteDriver)
        }
        iosMain {
            dependencies {
                implementation(libs.sqldelight.nativeDriver)
            }
            // UI-test entry points (UiTestSupport.kt) are for the iOS app's
            // Debug builds only. Xcode sets CONFIGURATION for the framework
            // build it drives; for Release the file is left out, so the
            // shipped framework has no way to reset, seed or re-clock the app.
            if (providers.environmentVariable("CONFIGURATION").orNull == "Release") {
                kotlin.exclude("**/di/UiTestSupport.kt")
            }
        }
        commonTest.dependencies {
            implementation(libs.kotlin.test)
            implementation(libs.kotlinx.coroutines.test)
        }
    }
}

sqldelight {
    databases {
        create("MonegingDatabase") {
            packageName.set("io.github.mktkhr.moneging.data.db")
            // Schema version 1 is the .sq files; every later change is a
            // numbered migration (.sqm) applied on start.
        }
    }
}
