package io.github.mktkhr.moneging.buildlogic

import com.android.build.gradle.internal.lint.AndroidLintAnalysisTask
import com.android.build.gradle.internal.lint.AndroidLintGlobalTask
import com.android.build.gradle.internal.lint.AndroidLintTask
import com.android.build.gradle.internal.lint.AndroidLintTextOutputTask
import com.android.build.gradle.internal.lint.LintOptionsInput
import dev.detekt.gradle.Detekt
import dev.detekt.gradle.extensions.FailOnSeverity
import org.gradle.api.Project
import org.gradle.api.Task
import org.gradle.api.file.FileCollection
import org.gradle.api.internal.TaskInternal
import org.gradle.api.specs.CompositeSpec
import org.jetbrains.kotlin.gradle.dsl.KotlinProjectExtension
import org.jetbrains.kotlin.gradle.plugin.KotlinSourceSet
import org.jlleitschuh.gradle.ktlint.tasks.BaseKtLintCheckTask
import org.jlleitschuh.gradle.ktlint.tasks.GenerateReportsTask
import java.io.File
import java.util.Collections
import java.util.WeakHashMap

/**
 * The final state of each detekt / ktlint / Android Lint task about to run:
 * enabled, no foreign `onlyIf`, the policy's configuration, no sources
 * filtered out beyond the build directory.
 */
internal class TaskStateVerifier(
    private val policy: QualityPolicy,
    private val scope: VerificationScope,
    private val problems: Problems,
) {
    fun verifyScheduledTasks() {
        scope.scheduled.filter(::isToolTask).forEach(::verifyTask)
    }

    private fun verifyTask(task: Task) {
        if (!task.enabled) problems.add("${task.path} is disabled")
        foreignOnlyIfPredicates(task).forEach { problems.add("${task.path} has an onlyIf predicate: $it") }
        when (task) {
            is Detekt -> verifyDetekt(task)
            is BaseKtLintCheckTask -> verifyNothingFilteredOut(task, task.source.files)
            is GenerateReportsTask -> verifyKtlintReport(task)
            is AndroidLintAnalysisTask -> verifyLintOptions(task.path, task.projectInputs.lintOptions)
            is AndroidLintTask -> verifyLintOptions(task.path, task.projectInputs.lintOptions)
            is AndroidLintTextOutputTask -> verifyLintTextOutput(task)
        }
    }

    // Every predicate other than Gradle's own "Task is enabled" one and, on
    // ktlint tasks, the ktlint plugin's own.
    private fun foreignOnlyIfPredicates(task: Task): List<String> {
        val specs = ((task as TaskInternal).onlyIf as? CompositeSpec<*>)?.specs.orEmpty()
        val isKtlint = task is BaseKtLintCheckTask || task is GenerateReportsTask
        val foreign = specs.filterNot { isOwnPredicate((it.privateField("spec") ?: it).javaClass.name, isKtlint) }
        return foreign.map(Any::toString)
    }

    private fun verifyDetekt(task: Detekt) {
        val config =
            task.config.files
                .map(File::getCanonicalFile)
                .toSet()
        if (config != setOf(policy.detektConfig.canonicalFile)) {
            problems.add("${task.path} uses detekt config $config instead of ${policy.detektConfig.canonicalFile}")
        }
        problems.compare(
            subject = task.path,
            actual =
                mapOf(
                    "all rules" to task.allRules.orNull,
                    "build upon default config" to task.buildUponDefaultConfig.orNull,
                    "disable default rule sets" to task.disableDefaultRuleSets.orNull,
                    "auto correct" to task.autoCorrect.orNull,
                    IGNORE_FAILURES to task.ignoreFailures.orNull,
                    "fail on severity" to task.failOnSeverity.orNull,
                ),
            required = DETEKT_SETTINGS,
        )
        // detekt reads a baseline only when the file exists (the plain
        // `detekt` task points at a conventional detekt-baseline.xml anyway).
        val knownFindings = task.baseline.orNull?.asFile
        if (knownFindings != null && knownFindings.exists()) {
            problems.add("${task.path} skips the known findings listed in $knownFindings")
        }
        verifyNothingFilteredOut(task, task.source.files)
    }

    private fun verifyKtlintReport(task: GenerateReportsTask) {
        problems.compare(
            subject = task.path,
            actual = mapOf(IGNORE_FAILURES to task.providerValue("getIgnoreFailures\$ktlint_gradle")),
            required = mapOf(IGNORE_FAILURES to false),
        )
        if (task.providerValue("getBaseline\$ktlint_gradle") != null) {
            problems.add("${task.path} skips the known findings of a ktlint findings file")
        }
    }

    private fun verifyLintOptions(
        path: String,
        options: LintOptionsInput,
    ) {
        val config = options.lintConfig.orNull?.run { asFile.canonicalFile }
        if (config != policy.lintConfig.canonicalFile) {
            problems.add("$path uses lint config ${config ?: "(none)"} instead of ${policy.lintConfig.canonicalFile}")
        }
        if (options.baseline.isPresent) problems.add("$path skips the known findings of a lint findings file")
        problems.compare(
            subject = path,
            actual =
                mapOf(
                    "check all warnings" to options.checkAllWarnings.orNull,
                    "warnings as errors" to options.warningsAsErrors.orNull,
                    ABORT_ON_ERROR to options.abortOnError.orNull,
                    "ignore warnings" to options.ignoreWarnings.orNull,
                    "check test sources" to options.checkTestSources.orNull,
                    "ignore test sources" to options.ignoreTestSources.orNull,
                    "disabled issues" to options.disable.orNull.orEmpty(),
                    "check only" to options.checkOnly.orNull.orEmpty(),
                ),
            required = LINT_SETTINGS,
        )
        // Through the getter: the value type (LintModelSeverity) lives in
        // lint-model, which is not on this build's compile classpath.
        val overrides = options.providerValue("getSeverityOverrides") as? Map<*, *>
        val silenced = overrides.orEmpty().filterValues { it != null && it.toString() in SILENCING_SEVERITIES }
        if (silenced.isNotEmpty()) problems.add("$path turns lint issues off: ${silenced.keys}")
    }

    private fun verifyLintTextOutput(task: AndroidLintTextOutputTask) {
        problems.compare(
            subject = task.path,
            actual = mapOf(ABORT_ON_ERROR to task.abortOnError.orNull),
            required = mapOf(ABORT_ON_ERROR to true),
        )
        if (task.hasBaseline.orNull == true) problems.add("${task.path} skips the known findings of a findings file")
    }

    // Only the build directory may be filtered out of a task's sources:
    // the files of the source roots the task was given against the files it
    // will actually analyse.
    private fun verifySourcesNotReplaced(
        task: Task,
        roots: FileCollection,
    ) {
        val sourceSet = task.namesakeSourceSet()
        if (sourceSet == null) {
            if (roots !== recordedSourceRoots[task]) {
                problems.add("${task.path} had its sources replaced (setSource) after the tool plugin set them")
            }
            return
        }
        val given = roots.asFileTree.files
        val left =
            sourceSet.kotlin.srcDirs
                .flatMap(scope::kotlinFilesUnder)
                .filterNot(given::contains)
        if (left.isNotEmpty()) {
            problems.add("${task.path} no longer analyses source set ${sourceSet.name}: ${scope.relative(left)}")
        }
    }

    private fun verifyNothingFilteredOut(
        task: Task,
        analysed: Set<File>,
    ) {
        val roots = task.privateField(SOURCE_ROOTS_FIELD) as? FileCollection
        if (roots == null) {
            problems.add("${task.path}: cannot read its source roots to verify them")
            return
        }
        verifySourcesNotReplaced(task, roots)
        val dropped =
            roots.asFileTree.files
                .filter { it.isKotlin() && !scope.isBuildOutput(it) }
                .filterNot(analysed::contains)
        if (dropped.isNotEmpty()) {
            problems.add("${task.path} filters product sources out of its analysis: ${scope.relative(dropped)}")
        }
    }
}

// The source roots each detekt / ktlint task had when the convention plugin
// configured it. setSource() swaps in a new collection object, so a later
// replacement is detectable by identity.
private val recordedSourceRoots: MutableMap<Task, Any?> = Collections.synchronizedMap(WeakHashMap())

/**
 * Records the source roots of every task of [type] when it is configured.
 *
 * Reliable only for the tasks whose tool plugin sets the sources before the
 * `configureEach` actions run (the type-resolution detekt tasks, ktlint's
 * Android source-set tasks, the Kotlin script tasks). A task named after a
 * Kotlin source set (`detekt<SourceSet>SourceSet`,
 * `runKtlint{Check,Format}Over<SourceSet>SourceSet`) gets its sources afterwards; it
 * is verified against that source set instead.
 */
internal fun <T : Task> Project.recordSourceRootsOf(type: Class<T>) {
    tasks.withType(type).configureEach { task -> recordedSourceRoots[task] = task.privateField(SOURCE_ROOTS_FIELD) }
}

private val SOURCE_SET_TASK = Regex("""^(?:detekt|runKtlint(?:Check|Format)Over)(\w+)SourceSet$""")

// The Kotlin source set a `...<SourceSet>SourceSet` tool task is named
// after, if the project has one of that name.
private fun Task.namesakeSourceSet(): KotlinSourceSet? {
    val match = SOURCE_SET_TASK.matchEntire(name)
    val sourceSets = project.extensions.findByType(KotlinProjectExtension::class.java)?.sourceSets
    if (match == null || sourceSets == null) return null
    return sourceSets.findByName(match.groupValues[1].replaceFirstChar(Char::lowercaseChar))
}

private fun isOwnPredicate(
    origin: String,
    isKtlint: Boolean,
): Boolean =
    when {
        origin.startsWith(GRADLE_ENABLED_SPEC) -> true
        isKtlint -> origin.startsWith(KTLINT_PACKAGE)
        else -> false
    }

internal fun isToolTask(task: Task): Boolean =
    task is Detekt ||
        task is BaseKtLintCheckTask ||
        task is GenerateReportsTask ||
        task is AndroidLintTask ||
        task is AndroidLintAnalysisTask ||
        task is AndroidLintTextOutputTask ||
        task is AndroidLintGlobalTask

// The unfiltered source roots of SourceTask and of ktlint's BaseKtLintCheckTask.
private const val SOURCE_ROOTS_FIELD = "sourceFiles"

// Gradle's own "Task is enabled" predicate is an inner class of AbstractTask.
private const val GRADLE_ENABLED_SPEC = "org.gradle.api.internal.AbstractTask$"
private const val KTLINT_PACKAGE = "org.jlleitschuh.gradle.ktlint."
private const val IGNORE_FAILURES = "ignore failures"
private const val ABORT_ON_ERROR = "abort on error"
private val SILENCING_SEVERITIES = setOf("IGNORE", "INFORMATIONAL")

private val DETEKT_SETTINGS =
    mapOf(
        "all rules" to true,
        "build upon default config" to true,
        "disable default rule sets" to false,
        "auto correct" to false,
        IGNORE_FAILURES to false,
        "fail on severity" to FailOnSeverity.Info,
    )

private val LINT_SETTINGS =
    mapOf(
        "check all warnings" to true,
        "warnings as errors" to true,
        ABORT_ON_ERROR to true,
        "ignore warnings" to false,
        "check test sources" to true,
        "ignore test sources" to false,
        "disabled issues" to emptySet<String>(),
        "check only" to emptySet<String>(),
    )
