package io.github.mktkhr.moneging.buildlogic

import com.android.build.gradle.internal.lint.AndroidLintGlobalTask
import com.android.build.gradle.internal.lint.AndroidLintTextOutputTask
import dev.detekt.gradle.Detekt
import org.gradle.api.Task
import org.gradle.language.base.plugins.LifecycleBasePlugin
import org.jlleitschuh.gradle.ktlint.tasks.GenerateReportsTask
import org.jlleitschuh.gradle.ktlint.tasks.KtLintCheckTask
import java.io.File

/**
 * The task graph still runs the policy: the lifecycle tasks still reach
 * every tool task, nothing is excluded, all Kotlin files are covered.
 */
internal class WiringVerifier(
    private val scope: VerificationScope,
    private val problems: Problems,
) {
    private val project = scope.project
    private val tasks = project.tasks
    private val ktlintReports by lazy {
        tasks.withType(GenerateReportsTask::class.java).filter { it.name.endsWith("Check") }
    }

    fun verifyWiring() {
        verifyBuildDirectory()
        verifyNotExcluded()
        scope.scheduled.forEach { task ->
            when {
                task.name == LifecycleBasePlugin.CHECK_TASK_NAME -> verifyCheck(task)
                task.name == DETEKT_ALL -> verifyDetektAll(task)
                task.name == KTLINT_CHECK -> verifyKtlintCheck(task)
                task is AndroidLintGlobalTask -> verifyLint(task)
            }
        }
    }

    private fun verifyBuildDirectory() {
        val projectDir = project.projectDir.toPath()
        val build = scope.buildDir.toPath()
        if (projectDir.startsWith(build) || build.startsWith(projectDir.resolve("src"))) {
            problems.add(
                "layout.buildDirectory (${scope.buildDir}) contains the project's sources, and everything " +
                    "under it is excluded from analysis",
            )
        }
    }

    // A policy task named in excludedTaskNames (-x). Any other spelling of
    // an exclusion still drops the task from the graph, which the lifecycle
    // checks below report.
    private fun verifyNotExcluded() {
        val excluded =
            project.gradle.startParameter.excludedTaskNames
                .map { it.removePrefix(":") }
        val prefix = if (project.path == ":") "" else "${project.path.removePrefix(":")}:"
        val policyTasks =
            tasks.names.filter { name ->
                POLICY_TASK_PREFIXES.any(name::startsWith) || name == LifecycleBasePlugin.CHECK_TASK_NAME
            }
        policyTasks
            .filter { name -> name in excluded || "$prefix$name" in excluded }
            .forEach { problems.add(":$prefix$it is excluded from the build (excludedTaskNames / -x)") }
    }

    private fun verifyCheck(check: Task) {
        // The ktlint plugin wires its per-source-set checks into `check`
        // directly, not through ktlintCheck.
        val required = listOf(DETEKT_ALL, "lint").mapNotNull(tasks::findByName) + ktlintReports
        requireScheduled(check, required)
    }

    private fun verifyDetektAll(detektAll: Task) {
        val detektTasks = tasks.withType(Detekt::class.java).toList()
        requireScheduled(detektAll, detektTasks)
        verifyCoverage(
            tool = "detekt",
            analysed = detektTasks.flatMap { it.source.files },
            product = scope.productKotlinFiles(),
        )
    }

    private fun verifyKtlintCheck(ktlintCheck: Task) {
        requireScheduled(ktlintCheck, ktlintReports)
        verifyCoverage(
            tool = "ktlint",
            analysed = tasks.withType(KtLintCheckTask::class.java).flatMap { it.source.files },
            product = scope.productKotlinFiles() + scope.buildScripts(),
        )
    }

    // `lint` must still print (and fail on) the report of every Android Lint
    // target of a Kotlin Multiplatform library, or of the application's
    // default variant. By name: realising the other variants' tasks here
    // would configure them after the graph is fixed; lintVital* only report
    // fatal issues.
    private fun verifyLint(lint: Task) {
        val textOutputs = tasks.withType(AndroidLintTextOutputTask::class.java)
        val reports = textOutputs.names.filterNot { it.startsWith("lintVital") }
        val scheduled = scope.scheduled.map(Task::getName).toSet()
        if (project.pluginManager.hasPlugin(KMP_LIBRARY_PLUGIN)) {
            reports.filterNot(scheduled::contains).forEach { problems.add("${lint.path} no longer runs $it") }
        } else if (reports.none(scheduled::contains)) {
            problems.add("${lint.path} no longer runs any lint report")
        }
    }

    private fun requireScheduled(
        aggregate: Task,
        members: List<Task>,
    ) {
        members.filterNot(scope.graph::hasTask).forEach { problems.add("${aggregate.path} no longer runs ${it.path}") }
    }

    private fun verifyCoverage(
        tool: String,
        analysed: List<File>,
        product: List<File>,
    ) {
        val covered = analysed.map(File::getCanonicalFile).toSet()
        val missing = product.filterNot { it.canonicalFile in covered }
        if (missing.isNotEmpty()) problems.add("no $tool task of ${project.path} analyses ${scope.relative(missing)}")
    }
}

private const val DETEKT_ALL = "detektAll"
private const val KTLINT_CHECK = "ktlintCheck"
private const val KMP_LIBRARY_PLUGIN = "com.android.kotlin.multiplatform.library"
private val POLICY_TASK_PREFIXES = listOf("detekt", "ktlint", "runKtlint", "lint")
