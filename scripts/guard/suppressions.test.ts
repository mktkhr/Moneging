// Regression coverage for scripts/guard/suppressions.sh (a thin wrapper around
// suppressions.ts), driven as a subprocess against throwaway git
// repositories: every directive and weakening switch it must catch, the
// strict values it must leave alone, and the registry's own rules.
import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { after, before, describe, it } from "node:test";

const SCRIPT = path.join(import.meta.dirname, "suppressions.sh");

function write(root: string, relative: string, content: string): void {
  const full = path.join(root, relative);

  mkdirSync(path.dirname(full), { recursive: true });
  writeFileSync(full, content);
}

function makeRepo(): string {
  const root = mkdtempSync(path.join(tmpdir(), "suppressions-repo-"));

  execFileSync("git", ["init", "-q"], { cwd: root });
  execFileSync("git", ["config", "user.email", "test@example.com"], { cwd: root });
  execFileSync("git", ["config", "user.name", "test"], { cwd: root });
  write(root, "quality/suppressions.allow", "# registry\n");
  write(root, "clients/kmp/sharedLogic/src/commonMain/kotlin/Clean.kt", "package x\n\nfun clean(): Int = 1\n");
  execFileSync("git", ["add", "-A"], { cwd: root });
  execFileSync("git", ["commit", "-q", "-m", "init"], { cwd: root });

  return root;
}

function runGuard(root: string): { status: number | null; stdout: string } {
  const result = spawnSync("sh", [SCRIPT], { cwd: root, encoding: "utf8" });

  return { status: result.status, stdout: result.stdout + result.stderr };
}

interface Case {
  readonly name: string;
  readonly file: string;
  readonly line: string;
  /** The directive reported, or null when the line must pass. */
  readonly directive: string | null;
}

const KT = "clients/kmp/sharedLogic/src/commonMain/kotlin/Probe.kt";
const KT_TEST = "clients/kmp/sharedLogic/src/commonTest/kotlin/ProbeTest.kt";
const KTS = "clients/kmp/sharedLogic/build.gradle.kts";
const LOGIC = "clients/kmp/build-logic/src/main/kotlin/Convention.kt";
const SWIFT = "clients/kmp/iosApp/iosApp/Probe.swift";
const XML = "clients/kmp/androidApp/src/main/res/layout/probe.xml";
const EDITORCONFIG = "clients/kmp/.editorconfig";
const XCCONFIG = "clients/kmp/iosApp/Configuration/Config.xcconfig";
const PBXPROJ = "clients/kmp/iosApp/iosApp.xcodeproj/project.pbxproj";

const CASES: readonly Case[] = [
  // Kotlin annotations, in every spelling.
  { name: "@Suppress", file: KT, line: '@Suppress("MagicNumber")', directive: "@Suppress" },
  { name: "@Suppress with a space", file: KT, line: '@Suppress ("MagicNumber")', directive: "@Suppress" },
  { name: "@kotlin.Suppress", file: KT, line: '@kotlin.Suppress("MagicNumber")', directive: "@Suppress" },
  { name: "@file:Suppress", file: KT, line: '@file:Suppress("MagicNumber")', directive: "@Suppress" },
  { name: "@file: Suppress", file: KT, line: '@file: Suppress("MagicNumber")', directive: "@Suppress" },
  { name: "@file:[Suppress]", file: KT, line: '@file:[Suppress("MagicNumber")]', directive: "@Suppress" },
  { name: "@get:Suppress", file: KT, line: '@get:Suppress("MagicNumber") val x = 1', directive: "@Suppress" },
  { name: "@field:Suppress", file: KT, line: '@field:Suppress("X") val x = 1', directive: "@Suppress" },
  { name: "@param:kotlin.Suppress", file: KT, line: '@param:kotlin.Suppress("X")', directive: "@Suppress" },
  { name: "@SuppressWarnings", file: KT, line: '@SuppressWarnings("unchecked")', directive: "@Suppress" },
  {
    name: "@java.lang.SuppressWarnings",
    file: KT,
    line: '@java.lang.SuppressWarnings("x")',
    directive: "@Suppress",
  },
  { name: "@SuppressLint", file: KT, line: '@SuppressLint("NewApi")', directive: "@Suppress" },
  {
    name: "@android.annotation.SuppressLint",
    file: KT,
    line: '@android.annotation.SuppressLint("NewApi")',
    directive: "@Suppress",
  },
  {
    name: "Suppress later in an @file:[...] list",
    file: KT,
    line: '@file:[JvmName("a") Suppress("x")]',
    directive: "@Suppress",
  },
  {
    name: "kotlin.Suppress later in an @[...] list",
    file: KT,
    line: '@[Deprecated("d") kotlin.Suppress("x")] fun f() = 1',
    directive: "@Suppress",
  },
  {
    name: "Suppress on a later line of an @file:[...] list",
    file: KT,
    line: '@file:[\n    JvmName("a")\n    Suppress("x")\n]',
    directive: "@Suppress",
  },
  { name: "@`Suppress`", file: KT, line: '@`Suppress`("MagicNumber")', directive: "@Suppress" },
  { name: "@file:`Suppress`", file: KT, line: '@file:`Suppress`("MagicNumber")', directive: "@Suppress" },
  { name: "@`kotlin`.`Suppress`", file: KT, line: '@`kotlin`.`Suppress`("X")', directive: "@Suppress" },
  { name: "@file:[`Suppress`]", file: KT, line: '@file:[JvmName("a") `Suppress`("x")]', directive: "@Suppress" },
  { name: "@file:[...] without Suppress", file: KT, line: '@file:[JvmName("a") JvmMultifileClass]', directive: null },
  { name: "typealias to Suppress", file: KT, line: "typealias S = kotlin.Suppress", directive: "Suppress-alias" },
  { name: "import alias of Suppress", file: KT, line: "import kotlin.Suppress as S", directive: "Suppress-alias" },
  { name: "//noinspection", file: KT, line: "//noinspection SpellCheckingInspection", directive: "noinspection" },
  { name: "// noinspection", file: KT, line: "// noinspection unused", directive: "noinspection" },
  { name: "ktlint-disable", file: KT, line: "// ktlint-disable", directive: "ktlint-disable" },
  { name: "ktlint:disable", file: KT, line: "/* ktlint:disable */", directive: "ktlint-disable" },
  { name: "@Ignore", file: KT_TEST, line: "@Ignore", directive: "@Ignore" },
  { name: "@kotlin.test.Ignore", file: KT_TEST, line: "@kotlin.test.Ignore", directive: "@Ignore" },
  { name: "@Disabled", file: KT_TEST, line: "@Disabled", directive: "@Ignore" },
  { name: "plain product code", file: KT, line: "fun suppressedCount(): Int = 0", directive: null },

  // Swift.
  { name: "swiftlint:disable", file: SWIFT, line: "// swiftlint:disable force_cast", directive: "swiftlint:disable" },
  {
    name: "swiftlint:disable:next",
    file: SWIFT,
    line: "// swiftlint:disable:next force_cast",
    directive: "swiftlint:disable",
  },
  { name: "swift-format-ignore", file: SWIFT, line: "// swift-format-ignore", directive: "swift-format-ignore" },
  {
    name: "swift-format-ignore-file",
    file: SWIFT,
    line: "// swift-format-ignore-file",
    directive: "swift-format-ignore",
  },
  { name: "XCTSkip", file: SWIFT, line: 'throw XCTSkip("later")', directive: "XCTSkip" },
  { name: "XCTSkipIf", file: SWIFT, line: "try XCTSkipIf(true)", directive: "XCTSkip" },
  { name: "XCTExpectFailure", file: SWIFT, line: 'XCTExpectFailure("x")', directive: "XCTExpectFailure" },
  { name: "withKnownIssue", file: SWIFT, line: "withKnownIssue { }", directive: "withKnownIssue" },
  { name: ".disabled(", file: SWIFT, line: '@Test(.disabled("x")) func t() {}', directive: ".disabled(" },
  { name: ".enabled(if:", file: SWIFT, line: "@Test(.enabled(if: false)) func t() {}", directive: ".enabled(if:" },

  // Android XML.
  { name: "tools:ignore", file: XML, line: '<View tools:ignore="ContentDescription" />', directive: "tools:ignore" },
  { name: "XML noinspection", file: XML, line: "<!--suppress AndroidDomInspection -->", directive: "noinspection" },
  {
    name: "nested lint.xml severity ignore",
    file: "clients/kmp/sharedLogic/lint.xml",
    line: '<issue id="SimpleDateFormat" severity="ignore" />',
    directive: "lint-severity",
  },
  {
    name: "nested lint.xml <ignore path>",
    file: "clients/kmp/sharedLogic/lint.xml",
    line: '<issue id="X"><ignore path="src" /></issue>',
    directive: "lint-ignore",
  },

  // ignoreFailures: only the literal false passes.
  { name: "ignoreFailures = false", file: KTS, line: "ignoreFailures = false", directive: null },
  { name: "ignoreFailures.set(false)", file: KTS, line: "ignoreFailures.set(false)", directive: null },
  { name: "ignoreFailures.disallowChanges()", file: KTS, line: "ignoreFailures.disallowChanges()", directive: null },
  { name: "ignoreFailures = true", file: KTS, line: "ignoreFailures = true", directive: "ignoreFailures" },
  { name: "ignoreFailures.set(true)", file: KTS, line: "ignoreFailures.set(true)", directive: "ignoreFailures" },
  { name: "ignoreFailures.set(flag)", file: KTS, line: "ignoreFailures.set(flag)", directive: "ignoreFailures" },
  {
    name: "ignoreFailures = project.hasProperty(...)",
    file: KTS,
    line: 'ignoreFailures = project.hasProperty("lax")',
    directive: "ignoreFailures",
  },
  {
    name: "ignoreFailures.convention(true)",
    file: KTS,
    line: "ignoreFailures.convention(true)",
    directive: "ignoreFailures",
  },
  { name: "ignoreFailures = falsey()", file: KTS, line: "ignoreFailures = falsey()", directive: "ignoreFailures" },
  { name: "isIgnoreFailures = true", file: KTS, line: "isIgnoreFailures = true", directive: "isIgnoreFailures" },
  { name: "ignoreFailures in build-logic", file: LOGIC, line: "ext.ignoreFailures.set(x)", directive: "ignoreFailures" },
  { name: "setIgnoreFailures(true)", file: KTS, line: "setIgnoreFailures(true)", directive: "setIgnoreFailures" },
  { name: "setIgnoreFailures(false)", file: KTS, line: "setIgnoreFailures(false)", directive: null },
  {
    name: "task.setIgnoreFailures(flag)",
    file: KTS,
    line: "task.setIgnoreFailures(flag)",
    directive: "setIgnoreFailures",
  },
  { name: "setIsIgnoreFailures(true)", file: KTS, line: "setIsIgnoreFailures(true)", directive: "setIsIgnoreFailures" },
  { name: "setAbortOnError(false)", file: KTS, line: "setAbortOnError(false)", directive: "setAbortOnError" },
  { name: "setWarningsAsErrors(false)", file: KTS, line: "setWarningsAsErrors(false)", directive: "setWarningsAsErrors" },
  { name: "setAllRules(false)", file: KTS, line: "setAllRules(false)", directive: "setAllRules" },
  {
    name: "setBaseline(file(...))",
    file: KTS,
    line: 'setBaseline(file("b.xml"))',
    directive: "setBaseline",
  },
  { name: "setBaseline(null)", file: KTS, line: "setBaseline(null)", directive: null },
  { name: "task.setEnabled(false)", file: KTS, line: 'tasks.named("lint") { setEnabled(false) }', directive: "task-disabled" },
  { name: "setOnlyIf { false }", file: KTS, line: "setOnlyIf { false }", directive: "task-disabled" },
  { name: "lint setDisable(...)", file: KTS, line: 'setDisable(setOf("NewApi"))', directive: "lint-disable" },
  { name: "read: ignoreFailures.orNull", file: LOGIC, line: "val v = t.ignoreFailures.orNull", directive: null },
  { name: "read: allRules.get()", file: LOGIC, line: "val v = t.allRules.get()", directive: null },
  { name: "read: baseline.isPresent", file: LOGIC, line: "if (t.baseline.isPresent) fail()", directive: null },
  {
    name: "a read does not excuse a write on the same line",
    file: LOGIC,
    line: "a.ignoreFailures.set(b.ignoreFailures.get())",
    directive: "ignoreFailures",
  },
  { name: "passing the property itself", file: KTS, line: "weaken(task.ignoreFailures)", directive: "ignoreFailures" },
  {
    name: "setProperty by name",
    file: KTS,
    line: 'setProperty("ignoreFailures", true)',
    directive: "ignoreFailures",
  },

  // Baselines, as DSL and as files.
  {
    name: "baseline = file(...)",
    file: KTS,
    line: 'baseline = file("detekt-baseline.xml")',
    directive: "baseline",
  },
  { name: "baseline.set(...)", file: KTS, line: "baseline.set(layout.projectDirectory.file(\"b\"))", directive: "baseline" },
  { name: "baselineFile", file: KTS, line: 'baselineFile = file("b.xml")', directive: "baselineFile" },
  { name: "baseline = null", file: KTS, line: "baseline = null", directive: null },
  { name: "baseline.set(null as RegularFile?)", file: LOGIC, line: "d.baseline.set(null as RegularFile?)", directive: null },
  {
    name: "a detekt baseline file",
    file: "clients/kmp/sharedLogic/detekt-baseline.xml",
    line: "<SmellBaseline/>",
    directive: "baseline-file",
  },
  {
    name: "a lint baseline file",
    file: "clients/kmp/androidApp/lint-baseline.xml",
    line: "<issues/>",
    directive: "baseline-file",
  },

  // Weakening switches.
  { name: "allWarningsAsErrors = true", file: KTS, line: "allWarningsAsErrors = true", directive: null },
  {
    name: "allWarningsAsErrors = false",
    file: KTS,
    line: "allWarningsAsErrors = false",
    directive: "allWarningsAsErrors",
  },
  {
    name: "allWarningsAsErrors.set(false)",
    file: KTS,
    line: "compilerOptions.allWarningsAsErrors.set(false)",
    directive: "allWarningsAsErrors",
  },
  { name: "suppressWarnings = true", file: KTS, line: "suppressWarnings = true", directive: "suppressWarnings" },
  { name: "suppressWarnings.set(false)", file: KTS, line: "suppressWarnings.set(false)", directive: null },
  {
    name: "-nowarn",
    file: KTS,
    line: 'freeCompilerArgs.add("-nowarn")',
    directive: "compiler-nowarn",
  },
  { name: "lint { disable += }", file: KTS, line: 'disable += "SimpleDateFormat"', directive: "lint-disable" },
  { name: "lint { disable.add }", file: KTS, line: 'disable.add("SimpleDateFormat")', directive: "lint-disable" },
  { name: "lint { disable(...) }", file: KTS, line: 'disable("SimpleDateFormat")', directive: "lint-disable" },
  { name: "lint checkOnly", file: KTS, line: 'checkOnly += "NewApi"', directive: "lint-disable" },
  { name: "ignoreWarnings = true", file: KTS, line: "ignoreWarnings = true", directive: "ignoreWarnings" },
  { name: "ignoreWarnings = false", file: KTS, line: "ignoreWarnings = false", directive: null },
  { name: "warningsAsErrors = false", file: KTS, line: "warningsAsErrors = false", directive: "warningsAsErrors" },
  { name: "abortOnError = false", file: KTS, line: "abortOnError = false", directive: "abortOnError" },
  { name: "checkAllWarnings = false", file: KTS, line: "checkAllWarnings = false", directive: "checkAllWarnings" },
  { name: "checkTestSources = false", file: KTS, line: "checkTestSources = false", directive: "checkTestSources" },
  { name: "allRules = false", file: KTS, line: "allRules = false", directive: "allRules" },
  {
    name: "buildUponDefaultConfig = false",
    file: KTS,
    line: "buildUponDefaultConfig = false",
    directive: "buildUponDefaultConfig",
  },
  {
    name: "failOnSeverity = Never",
    file: KTS,
    line: "failOnSeverity = FailOnSeverity.Never",
    directive: "failOnSeverity",
  },
  {
    name: "failOnSeverity = Info",
    file: KTS,
    line: "failOnSeverity = dev.detekt.gradle.extensions.FailOnSeverity.Info",
    directive: null,
  },
  { name: "ignoredVariants", file: KTS, line: 'ignoredVariants = listOf("release")', directive: "ignoredVariants" },
  { name: "task enabled = false", file: KTS, line: "enabled = false", directive: "task-disabled" },
  { name: "task enabled.set(false)", file: KTS, line: "enabled.set(false)", directive: "task-disabled" },
  { name: "task onlyIf { false }", file: KTS, line: "onlyIf { false }", directive: "task-disabled" },
  { name: "comment mentioning baseline", file: KTS, line: "// no baseline is used", directive: null },
  {
    name: "ktlint_*=disabled in .editorconfig",
    file: EDITORCONFIG,
    line: "ktlint_standard_no-wildcard-imports = disabled",
    directive: "ktlint-editorconfig-disabled",
  },
  {
    name: "ktlint_standard = disabled in .editorconfig",
    file: EDITORCONFIG,
    line: "ktlint_standard = disabled",
    directive: "ktlint-editorconfig-disabled",
  },
  { name: "ktlint_*=enabled in .editorconfig", file: EDITORCONFIG, line: "ktlint_standard_x = enabled", directive: null },
  {
    name: "SWIFT_TREAT_WARNINGS_AS_ERRORS = NO in xcconfig",
    file: XCCONFIG,
    line: "SWIFT_TREAT_WARNINGS_AS_ERRORS = NO",
    directive: "SWIFT_TREAT_WARNINGS_AS_ERRORS",
  },
  {
    name: "SWIFT_TREAT_WARNINGS_AS_ERRORS=YES in xcconfig",
    file: XCCONFIG,
    line: "SWIFT_TREAT_WARNINGS_AS_ERRORS=YES",
    directive: null,
  },
  {
    name: "SWIFT_TREAT_WARNINGS_AS_ERRORS = NO; in pbxproj",
    file: PBXPROJ,
    line: "\t\t\t\tSWIFT_TREAT_WARNINGS_AS_ERRORS = NO;",
    directive: "SWIFT_TREAT_WARNINGS_AS_ERRORS",
  },
  {
    name: "SWIFT_TREAT_WARNINGS_AS_ERRORS = YES; in pbxproj",
    file: PBXPROJ,
    line: "\t\t\t\tSWIFT_TREAT_WARNINGS_AS_ERRORS = YES;",
    directive: null,
  },
  {
    name: "SWIFT_SUPPRESS_WARNINGS = YES",
    file: PBXPROJ,
    line: "\t\t\t\tSWIFT_SUPPRESS_WARNINGS = YES;",
    directive: "inhibit-warnings",
  },
  {
    name: "a nested .swiftlint.yml",
    file: "clients/kmp/iosApp/iosApp/.swiftlint.yml",
    line: "disabled_rules: [force_cast]",
    directive: "swiftlint-config",
  },
];

describe("suppressions.sh", () => {
  let root = "";

  before(() => {
    root = makeRepo();
  });

  after(() => {
    rmSync(root, { recursive: true, force: true });
  });

  it("passes on a tree with no directives", () => {
    const result = runGuard(root);

    assert.equal(result.status, 0, result.stdout);
    assert.match(result.stdout, /0 directive\(s\), all registered/u);
  });

  for (const testCase of CASES) {
    const verdict = testCase.directive === null ? "passes" : `flags [${testCase.directive}]`;

    it(`${verdict}: ${testCase.name}`, () => {
      const full = path.join(root, testCase.file);

      write(root, testCase.file, `${testCase.line}\n`);
      try {
        const result = runGuard(root);

        if (testCase.directive === null) {
          assert.equal(result.status, 0, result.stdout);
        } else {
          assert.equal(result.status, 1, result.stdout);
          assert.ok(
            result.stdout.includes(`unregistered suppression [${testCase.directive}]: ${testCase.file}`),
            result.stdout,
          );
        }
      } finally {
        rmSync(full, { force: true });
      }
    });
  }

  it("accepts a directive once it is registered, and rejects it again when the line changes", () => {
    const line = '@Suppress("MagicNumber")';

    write(root, KT, `${line}\n`);
    write(root, "quality/suppressions.allow", `# reason: test\n${KT} :: @Suppress :: ${line}\n`);
    try {
      assert.equal(runGuard(root).status, 0);

      write(root, KT, '@Suppress("MagicNumber", "LongMethod")\n');
      const result = runGuard(root);

      assert.equal(result.status, 1);
      assert.match(result.stdout, /unregistered suppression \[@Suppress\]/u);
      assert.match(result.stdout, /stale registry entry/u);
    } finally {
      rmSync(path.join(root, KT), { force: true });
      write(root, "quality/suppressions.allow", "# registry\n");
    }
  });

  it("fails on a stale registry entry whose directive is gone", () => {
    write(root, "quality/suppressions.allow", `${KT} :: @Suppress :: @Suppress("Gone")\n`);
    try {
      const result = runGuard(root);

      assert.equal(result.status, 1);
      assert.match(result.stdout, /stale registry entry: .*@Suppress\("Gone"\)/u);
    } finally {
      write(root, "quality/suppressions.allow", "# registry\n");
    }
  });

  it("does not scan the harness's own policy files", () => {
    write(root, "quality/kotlin/android-lint.xml", '<issue id="GradleDependency" severity="ignore" />\n');
    try {
      assert.equal(runGuard(root).status, 0);
    } finally {
      rmSync(path.join(root, "quality/kotlin"), { recursive: true, force: true });
    }
  });

  it("does not scan git-ignored build output", () => {
    write(root, ".gitignore", "build/\n");
    write(root, "clients/kmp/sharedLogic/build/generated/G.kt", '@Suppress("X")\n');
    try {
      assert.equal(runGuard(root).status, 0);
    } finally {
      rmSync(path.join(root, ".gitignore"), { force: true });
      rmSync(path.join(root, "clients/kmp/sharedLogic/build"), { recursive: true, force: true });
    }
  });
});
