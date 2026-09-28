package io.github.mktkhr.moneging.buildlogic

import org.gradle.api.GradleException
import org.gradle.api.Project
import org.gradle.api.Task
import org.gradle.api.execution.TaskExecutionGraph
import java.io.File

/** The configuration files the policy tasks must use. */
internal data class QualityPolicy(
    val detektConfig: File,
    val lintConfig: File,
)

/**
 * Fails the build when a policy task that is about to run was weakened after
 * the convention plugin configured it.
 *
 * Locking a value (`disallowChanges()`) only stops later writes to that one
 * property, and the task-level values cannot even be locked (the tool
 * plugins configure their tasks after every `configureEach` action). A module
 * build script can still reach the tasks themselves, so the final state is
 * verified once the task graph is known (`taskGraph.whenReady`): by then
 * every build script, `afterEvaluate` and `configureEach` action has run.
 * Checked, for the detekt / ktlint / Android Lint tasks in the graph:
 * - [TaskStateVerifier]: each is enabled, carries no `onlyIf` predicate
 *   beyond Gradle's and the tool plugin's own, uses the policy's
 *   configuration (config file, all rules, failures fail, no baseline) and
 *   filters nothing but the project's build directory out of its sources;
 * - [WiringVerifier]: `check` still runs `detektAll`, `lint` and the ktlint
 *   checks, each of those still runs its tool tasks, no policy task is in
 *   `excludedTaskNames` (`-x`), the detekt (and the ktlint) tasks together
 *   still cover every Kotlin file of the project, and the build directory
 *   does not swallow the sources.
 */
internal fun Project.verifyFinalPolicyState(policy: QualityPolicy) {
    gradle.taskGraph.whenReady { graph ->
        val scope = VerificationScope(this, graph)
        val problems = Problems()
        TaskStateVerifier(policy, scope, problems).verifyScheduledTasks()
        WiringVerifier(scope, problems).verifyWiring()
        problems.throwIfAny(path)
    }
}

/** What the verifiers look at: one project and the tasks it is about to run. */
internal class VerificationScope(
    val project: Project,
    val graph: TaskExecutionGraph,
) {
    val buildDir: File =
        project.layout.buildDirectory
            .get()
            .asFile

    /** This project's tasks in the graph (the others are not realised: that would configure them too late). */
    val scheduled: List<Task> = graph.allTasks.filter { it.project == project }

    fun isBuildOutput(file: File) = file.toPath().startsWith(buildDir.toPath())

    fun relative(files: Collection<File>) = files.map { it.relativeTo(project.projectDir).path }.sorted()

    /** Every Kotlin file under `src/`, the tree the source sets live in. */
    fun productKotlinFiles(): List<File> = kotlinFilesUnder(project.file("src"))

    /** The Kotlin files under [dir], outside the build directory. */
    fun kotlinFilesUnder(dir: File): List<File> =
        dir
            .walkTopDown()
            .filter { it.isFile && it.isKotlin() && !isBuildOutput(it) }
            .toList()

    /** The project's own Gradle Kotlin scripts, which ktlint checks too. */
    fun buildScripts(): List<File> =
        project.projectDir
            .listFiles()
            .orEmpty()
            .filter { it.isFile && it.name.endsWith(".kts") }
}

internal fun File.isKotlin() = name.endsWith(".kt") || name.endsWith(".kts")

/** The weakenings found, reported together. */
internal class Problems {
    private val found = mutableListOf<String>()

    fun add(problem: String) {
        found += problem
    }

    fun compare(
        subject: String,
        actual: Map<String, Any?>,
        required: Map<String, Any>,
    ) {
        required
            .filter { (name, value) -> actual[name] != value }
            .forEach { (name, value) ->
                found += "$subject sets $name = ${actual[name] ?: "(unset)"} (the policy requires $value)"
            }
    }

    fun throwIfAny(projectPath: String) {
        if (found.isEmpty()) return
        throw GradleException(
            "Project '$projectPath' weakens the quality gates configured by the moneging.quality convention " +
                "plugin (clients/kmp/build-logic). Remove the override from the build script:\n" +
                found.joinToString("\n") { "  - $it" },
        )
    }
}
