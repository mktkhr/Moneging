import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.androidMultiplatformLibrary)
    alias(libs.plugins.composeMultiplatform)
    alias(libs.plugins.composeCompiler)
    alias(libs.plugins.detekt)
    alias(libs.plugins.ktlintGradle)
}

kotlin {
    compilerOptions {
        allWarningsAsErrors = true
    }

    android {
        namespace = "io.github.mktkhr.moneging.sharedUI"
        compileSdk = libs.versions.android.compileSdk.get().toInt()
        minSdk = libs.versions.android.minSdk.get().toInt()

        compilerOptions {
            jvmTarget = JvmTarget.JVM_11
        }
        androidResources {
            enable = true
        }
        withHostTest {
            isIncludeAndroidResources = true
        }
        withDeviceTestBuilder {
            sourceSetTreeName = "test"
        }.configure {
            instrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        }
    }

    sourceSets {
        androidMain.dependencies {
            implementation(libs.compose.uiToolingPreview)
            implementation(libs.compose.uiTooling)
        }
        commonMain.dependencies {
            api(project(":sharedLogic"))
            implementation(libs.compose.runtime)
            implementation(libs.compose.foundation)
            implementation(libs.compose.material3)
            implementation(libs.compose.ui)
            implementation(libs.compose.components.resources)
            implementation(libs.compose.uiToolingPreview)
            implementation(libs.androidx.lifecycle.viewmodelCompose)
            implementation(libs.androidx.lifecycle.runtimeCompose)
        }
        commonTest.dependencies {
            implementation(libs.kotlin.test)
        }
    }
}

dependencies {
    androidRuntimeClasspath(libs.compose.uiTooling)
}

detekt {
    allRules = true
    buildUponDefaultConfig = false
    config.setFrom(files("${rootProject.projectDir}/../../quality/kotlin/detekt.yml"))
    // See sharedLogic/build.gradle.kts: detekt-gradle-plugin 1.23.8 has no
    // type-resolution task for the shared commonTest KMP source set, so the
    // plain `detekt` task is pointed at every source directory instead.
    source.setFrom(
        "src/commonMain/kotlin",
        "src/commonTest/kotlin",
    )
}

tasks.withType<io.gitlab.arturbosch.detekt.Detekt>().configureEach {
    // detekt's KMP type-resolution tasks add the Compose resource generator's
    // output directory as its own source root (it lives under build/), so a
    // relative "**/build/**" glob never matches; filter by absolute path.
    exclude { it.file.path.contains("/build/") }
}

ktlint {
    version.set("1.8.0")
    ignoreFailures.set(false)
}