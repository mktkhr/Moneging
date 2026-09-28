package io.github.mktkhr.moneging.buildlogic

import dev.detekt.gradle.Detekt
import org.gradle.api.GradleException
import org.gradle.api.logging.StandardOutputListener
import org.gradle.api.services.BuildService
import org.gradle.api.services.BuildServiceParameters
import java.util.concurrent.ConcurrentHashMap

/**
 * detekt's compiler-error count, checked against the one expected.
 *
 * A type-resolution task (non-empty classpath, e.g. `detektMainAndroid`)
 * compiles its sources with the Kotlin compiler first. detekt 2.0.0-alpha.6
 * analyses commonMain and androidMain as ONE module, so every expect/actual
 * pair is reported as compiler errors, and detekt only prints their count:
 *
 *   There were 3 compiler errors found during analysis. ...
 *
 * Measured (with `debug = true`) for one top-level `expect fun` in
 * commonMain and its `actual fun` in androidMain, the 3 errors are:
 * - actual: "has no corresponding expected declaration"
 * - actual: "expect and corresponding actual are declared in the same module"
 * - expect: "expect and corresponding actual are declared in the same module"
 *
 * These errors are an artefact of the analysis, not of the code, and they
 * cannot be silenced. But a real compiler error (an unresolved reference,
 * a type mismatch - anything that makes detekt's type-resolved rules blind)
 * prints the same one line with a larger number. So the count must be
 * exactly [ERRORS_PER_EXPECT_ACTUAL_PAIR] per `actual` declaration in the
 * task's sources (0 for a task without type resolution); anything else fails
 * the task. If a new kind of expect/actual declaration (e.g. members of an
 * `expect class`) yields a different count, this fails too: investigate with
 * `debug = true` in a scratch copy and extend the rule here, never loosen it.
 *
 * detekt prints the line to standard output, and Gradle hands a task's
 * output listener everything printed while it is registered - by any task.
 * So the type-resolution tasks (the only ones that compile, hence the only
 * ones that can print it) run one at a time ([DetektAnalysisSlot]); the
 * source-set tasks still run in parallel with them.
 */
internal const val ERRORS_PER_EXPECT_ACTUAL_PAIR = 3

private val COMPILER_ERRORS = Regex("""There were (\d+) compiler errors found during analysis""")
private val ACTUAL_DECLARATION =
    Regex("""\bactual\s+(?:[a-z]+\s+)*(?:fun|val|var|class|object|interface|typealias|constructor)\b""")

// The listener capturing detekt's console output, per running task path.
private val listeners = ConcurrentHashMap<String, CapturingListener>()

/** One type-resolution detekt task at a time, so its console output is its own. */
interface DetektAnalysisSlot : BuildService<BuildServiceParameters.None>

internal fun Detekt.verifyCompilerErrorCount() {
    // Source-set tasks (and the plain `detekt` task) never compile, so never
    // print the line: they need neither the slot nor the capture.
    if (name.endsWith("SourceSet") || name == "detekt") return
    val slot =
        project.gradle.sharedServices.registerIfAbsent("monegingDetektAnalysisSlot", DetektAnalysisSlot::class.java) {
            it.maxParallelUsages.set(1)
        }
    usesService(slot)
    doFirst { task ->
        val listener = CapturingListener()
        listeners[task.path] = listener
        task.logging.addStandardOutputListener(listener)
    }
    doLast { task ->
        val listener = listeners.remove(task.path)
        listener?.let { task.logging.removeStandardOutputListener(it) }
        checkCompilerErrorCount(task as Detekt, listener?.text().orEmpty())
    }
}

private class CapturingListener : StandardOutputListener {
    private val output = StringBuilder()

    override fun onOutput(text: CharSequence) {
        synchronized(output) { output.append(text) }
    }

    fun text(): String = synchronized(output) { output.toString() }
}

private fun checkCompilerErrorCount(
    task: Detekt,
    output: String,
) {
    val actual = COMPILER_ERRORS.find(output)?.let { it.groupValues[1].toInt() } ?: 0
    val pairs =
        if (task.classpath.isEmpty) {
            0
        } else {
            task.source.files.sumOf { file -> ACTUAL_DECLARATION.findAll(file.readText()).count() }
        }
    val expected = pairs * ERRORS_PER_EXPECT_ACTUAL_PAIR
    if (actual != expected) {
        throw GradleException(
            "${task.path}: detekt reported $actual compiler error(s) during analysis, expected $expected " +
                "($ERRORS_PER_EXPECT_ACTUAL_PAIR per expect/actual pair x $pairs `actual` declaration(s)). " +
                "A compiler error hides code from detekt's type-resolved rules: fix it (run the task with " +
                "detekt debug output to see the messages). See DetektCompilerErrors.kt.",
        )
    }
}
