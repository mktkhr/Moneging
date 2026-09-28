import org.jetbrains.kotlin.gradle.dsl.JvmTarget

// The AC-B acceptance tests (PRODUCT.md §7): Kotlin tests of the shared logic,
// in src/commonTest/kotlin, run on the Android host and the iOS simulator
// against :sharedLogic. Included in the Gradle build only by
// `make acceptance-shared` (clients/kmp/settings.gradle.kts).
plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.androidMultiplatformLibrary)
    // The same static-analysis policy as the product modules.
    id("moneging.quality")
}

// Build output stays out of acceptance/ (tracked, protected): under
// clients/kmp/build like build-logic's. `make status` reads the JUnit XML of
// both test tasks (testAndroidHostTest, iosSimulatorArm64Test) from its
// test-results/.
layout.buildDirectory = rootDir.resolve("build/acceptance-shared")

kotlin {
    iosSimulatorArm64()

    android {
        namespace = "io.github.mktkhr.moneging.acceptance"
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
        withHostTest {}
    }

    sourceSets {
        commonTest.dependencies {
            implementation(project(":sharedLogic"))
            implementation(libs.kotlin.test)
        }
    }
}
