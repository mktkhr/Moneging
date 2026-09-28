package io.github.mktkhr.moneging.buildlogic

import com.android.build.api.dsl.ApplicationExtension
import com.android.build.api.dsl.KotlinMultiplatformAndroidLibraryTarget
import com.android.build.api.dsl.Lint
import dev.detekt.gradle.Detekt
import dev.detekt.gradle.extensions.DetektExtension
import dev.detekt.gradle.extensions.FailOnSeverity
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.api.artifacts.VersionCatalogsExtension
import org.gradle.api.file.RegularFile
import org.gradle.language.base.plugins.LifecycleBasePlugin
import org.jetbrains.kotlin.gradle.dsl.KotlinMultiplatformExtension
import org.jetbrains.kotlin.gradle.tasks.KotlinCompilationTask
import org.jlleitschuh.gradle.ktlint.KtlintExtension
import java.io.File

/**
 * The Moneging static-analysis policy for one Gradle project.
 *
 * Part of the Repository Harness: every strictness switch of the Kotlin
 * toolchain lives here, so a module build script cannot weaken it by editing
 * its own `lint {}` / `detekt {}` / `ktlint {}` / `compilerOptions {}`
 * blocks - it only applies `id("moneging.quality")`. The switched-on values
 * are locked with `disallowChanges()` where Gradle allows it, so a later
 * override fails the build instead of silently winning.
 *
 * - Kotlin compiler: every warning is an error on every compilation task.
 * - ktlint: pinned CLI version from the version catalog, failures fail.
 * - detekt: all rules, `quality/kotlin/detekt.yml`, any finding fails, no
 *   baseline; `detektAll` runs every detekt task of the project and `check`
 *   depends on it.
 * - Android Lint: every check, warnings are errors,
 *   `quality/kotlin/android-lint.xml`, test sources included. Kotlin
 *   Multiplatform library modules also get `com.android.lint`, without which
 *   AGP 9 never analyses their main (commonMain + androidMain) code.
 */
class QualityConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) {
        val qualityDir =
            target.rootProject.layout.projectDirectory
                .dir("../../quality/kotlin")
                .asFile
        target.lockKotlinWarnings()
        target.applyKtlintPolicy()
        target.applyDetektPolicy(File(qualityDir, "detekt.yml"))
        target.applyAndroidLintPolicy(File(qualityDir, "android-lint.xml"))
    }
}

private const val BUILD_OUTPUT_SEGMENT = "/build/"

private fun Project.lockKotlinWarnings() {
    tasks.withType(KotlinCompilationTask::class.java).configureEach { task ->
        task.compilerOptions.allWarningsAsErrors.set(true)
        task.compilerOptions.allWarningsAsErrors.disallowChanges()
        task.compilerOptions.suppressWarnings.set(false)
        task.compilerOptions.suppressWarnings.disallowChanges()
    }
}

private fun Project.applyKtlintPolicy() {
    pluginManager.apply("org.jlleitschuh.gradle.ktlint")
    val ktlintVersion =
        extensions
            .getByType(VersionCatalogsExtension::class.java)
            .named("libs")
            .findVersion("ktlint")
            .orElseThrow { IllegalStateException("libs.versions.toml has no 'ktlint' version") }
            .requiredVersion
    val ktlint = extensions.getByType(KtlintExtension::class.java)
    ktlint.version.set(ktlintVersion)
    ktlint.version.disallowChanges()
    ktlint.android.set(pluginManager.hasPlugin("com.android.application"))
    ktlint.ignoreFailures.set(false)
    ktlint.ignoreFailures.disallowChanges()
    ktlint.filter { filter ->
        // Generated source roots (e.g. the Compose resource generator's)
        // live under build/; a relative "**/build/**" glob does not match
        // them, so filter by absolute path.
        filter.exclude { it.file.path.contains(BUILD_OUTPUT_SEGMENT) }
    }
}

private fun Project.applyDetektPolicy(configFile: File) {
    pluginManager.apply("dev.detekt")
    val detekt = extensions.getByType(DetektExtension::class.java)
    // Each value is set, then locked, one property per line: the guard in
    // scripts/guard/suppressions.ts accepts only these exact forms.
    detekt.allRules.set(true)
    detekt.allRules.disallowChanges()
    // detekt 2 runs only the rules present in the effective configuration:
    // without the default config underneath quality/kotlin/detekt.yml,
    // allRules would activate just the handful of rules that file names.
    detekt.buildUponDefaultConfig.set(true)
    detekt.buildUponDefaultConfig.disallowChanges()
    detekt.disableDefaultRuleSets.set(false)
    detekt.disableDefaultRuleSets.disallowChanges()
    detekt.autoCorrect.set(false)
    detekt.autoCorrect.disallowChanges()
    detekt.config.setFrom(configFile)
    detekt.config.disallowChanges()
    detekt.failOnSeverity.set(FailOnSeverity.Info)
    detekt.failOnSeverity.disallowChanges()
    detekt.ignoreFailures.set(false)
    detekt.ignoreFailures.disallowChanges()
    detekt.baseline.set(null as RegularFile?)
    detekt.baseline.disallowChanges()
    detekt.ignoredVariants.set(emptyList())
    detekt.ignoredVariants.disallowChanges()
    detekt.ignoredBuildTypes.set(emptyList())
    detekt.ignoredBuildTypes.disallowChanges()
    detekt.ignoredFlavors.set(emptyList())
    detekt.ignoredFlavors.disallowChanges()
    tasks.withType(Detekt::class.java).configureEach { task ->
        task.exclude { it.file.path.contains(BUILD_OUTPUT_SEGMENT) }
        task.ignoreFailures.set(false)
        task.failOnSeverity.set(FailOnSeverity.Info)
        task.baseline.set(null as RegularFile?)
        task.allRules.set(true)
        task.buildUponDefaultConfig.set(true)
    }
    val detektAll =
        tasks.register("detektAll") { task ->
            task.description = "Runs every detekt task of this project (type-resolution and source-set ones)."
            task.group = LifecycleBasePlugin.VERIFICATION_GROUP
            task.dependsOn(tasks.withType(Detekt::class.java))
        }
    dependOnFromCheck(detektAll)
}

private fun Project.applyAndroidLintPolicy(config: File) {
    pluginManager.withPlugin("com.android.application") {
        val lint = extensions.getByType(ApplicationExtension::class.java).lint
        lint.applyPolicy(config)
        lint.checkDependencies = true
        dependOnFromCheck("lint")
    }
    pluginManager.withPlugin("com.android.kotlin.multiplatform.library") {
        // Without this plugin AGP 9 registers Android Lint for the module's
        // host tests only, never for its main code.
        pluginManager.apply("com.android.lint")
        extensions
            .getByType(KotlinMultiplatformExtension::class.java)
            .targets
            .withType(KotlinMultiplatformAndroidLibraryTarget::class.java)
            .configureEach { target -> target.lint.applyPolicy(config) }
        dependOnFromCheck("lint")
    }
}

private fun Project.dependOnFromCheck(dependency: Any) {
    plugins.withType(LifecycleBasePlugin::class.java) {
        tasks.named(LifecycleBasePlugin.CHECK_TASK_NAME) { check -> check.dependsOn(dependency) }
    }
}

private fun Lint.applyPolicy(config: File) {
    checkAllWarnings = true
    warningsAsErrors = true
    abortOnError = true
    ignoreWarnings = false
    checkTestSources = true
    ignoreTestSources = false
    lintConfig = config
    baseline = null
}
