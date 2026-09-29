/**
 * Suppression guard.
 *
 * Static checks are only worth something when they cannot be silenced ad hoc.
 * This guard fails when a suppression directive, or a switch that weakens a
 * gate, exists in the working tree without being registered in
 * quality/suppressions.allow. Registering one is a reviewed change to the
 * Repository Harness, not something done in passing.
 *
 * Scanned: every tracked or untracked-but-not-ignored file
 * (`git ls-files -co --exclude-standard`) except the harness's own policy
 * files (quality/, scripts/guard/, .claude/, docs/) and Markdown prose.
 *
 * Registry line format (one per line, '#' starts a comment). The source line
 * is part of the key so that unrelated edits shifting line numbers do not
 * matter, while any change to the suppressed line itself must be
 * re-registered:
 *   <path relative to repository root> :: <directive> :: <trimmed source line>
 * A registry entry that no longer matches any finding is stale and fails too.
 */
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";

export interface Finding {
  readonly file: string;
  /** 1-based; 0 for a finding about the file itself (e.g. a baseline file). */
  readonly line: number;
  readonly directive: string;
  readonly code: string;
}

interface Rule {
  readonly directive: string;
  readonly pattern: RegExp;
}

/**
 * A property whose only acceptable value is fixed. Every mention of it is a
 * finding unless it assigns exactly that value (`= v`, `.set(v)`), locks it
 * (`.disallowChanges()`) or only reads it (`.orNull`, `.get()`,
 * `.isPresent` - the convention plugin's final-state verification):
 * `.set(flag)`, `= project.hasProperty(...)`, `.convention(true)`, passing
 * the property itself somewhere, a multi-line assignment and so on are all
 * flagged.
 * The Java-setter form (`setIgnoreFailures(v)`) is held to the same value.
 */
interface ValueGuard {
  readonly name: string;
  /** The property name as it appears after `set` in its Java setter. */
  readonly setter: string;
  readonly allowed: string;
}

const EXCLUDED_PREFIXES = ["quality/", "scripts/guard/", ".claude/", "docs/"];

// Kotlin/Java source (product, tests and build scripts alike).
const KOTLIN_RULES: readonly Rule[] = [
  // @Suppress, @Suppress ("X"), @kotlin.Suppress, @file:/@get:/@field:...
  // use-site targets, @file:[Suppress(...)], @SuppressWarnings, @SuppressLint,
  // and any of them with backtick-quoted names (@`Suppress`, @`kotlin`.`Suppress`).
  // Suppress anywhere inside a bracketed annotation list
  // (@file:[JvmName("a") Suppress("x")]), also across lines, is caught by
  // bracketSuppressLines().
  {
    directive: "@Suppress",
    pattern: /@\s*(?:`?[a-z]+`?\s*:\s*)?\[?\s*(?:[\w.`]+\.)?`?Suppress(?:Warnings|Lint)?\b/u,
  },
  // An alias for any of the above.
  { directive: "Suppress-alias", pattern: /\btypealias\s+\w+\s*=\s*(?:[\w.]+\.)?Suppress\w*/u },
  { directive: "Suppress-alias", pattern: /\bimport\s+[\w.]*\bSuppress\w*\s+as\s+\w+/u },
  { directive: "noinspection", pattern: /\bnoinspection\b/u },
  { directive: "ktlint-disable", pattern: /ktlint[-:]disable/u },
  { directive: "@Ignore", pattern: /@\s*(?:[\w.]+\.)?(?:Ignore|Disabled)\b/u },
];

const SWIFT_RULES: readonly Rule[] = [
  { directive: "swiftlint:disable", pattern: /swiftlint:disable/u },
  { directive: "swift-format-ignore", pattern: /swift-format-ignore/u },
  { directive: "XCTSkip", pattern: /\bXCTSkip/u },
  { directive: "XCTExpectFailure", pattern: /\bXCTExpectFailure\b/u },
  { directive: "withKnownIssue", pattern: /\bwithKnownIssue\b/u },
];

// Swift Testing traits that switch a test off. Outside test sources the same
// spelling is SwiftUI's `.disabled(_:)` view modifier, which is product code.
const SWIFT_TEST_RULES: readonly Rule[] = [
  { directive: ".disabled(", pattern: /\.disabled\s*\(/u },
  { directive: ".enabled(if:", pattern: /\.enabled\s*\(\s*if\s*:/u },
];

/** A Swift file of a test target: a `…Tests/` directory (iosAppUITests) or the acceptance suite. */
function isSwiftTestSource(file: string): boolean {
  return /(?:^|\/)(?:[^/]*Tests|acceptance)\//u.test(file);
}

const XML_RULES: readonly Rule[] = [
  { directive: "tools:ignore", pattern: /\btools:ignore\s*=/u },
  { directive: "noinspection", pattern: /\bnoinspection\b|<!--\s*suppress\b/u },
  // A lint.xml outside quality/ that turns an issue off.
  { directive: "lint-severity", pattern: /\bseverity\s*=\s*["'](?:ignore|informational)["']/u },
  { directive: "lint-ignore", pattern: /<\s*ignore\b/u },
];

// Gradle build logic: *.kts, *.gradle and the convention plugin sources.
const BUILD_RULES: readonly Rule[] = [
  {
    directive: "task-disabled",
    pattern: /\b(?:is)?[Ee]nabled\s*=\s*false\b|\benabled\.set\(\s*false\s*\)|\bset(?:Is)?Enabled\s*\(\s*false\b/u,
  },
  { directive: "task-disabled", pattern: /\b(?:set)?[Oo]nlyIf\s*(?:\(|\{)\s*(?:\{\s*)?false\b/u },
  // Android Lint DSL: turning issues off or narrowing the check set.
  {
    directive: "lint-disable",
    pattern: /\b(?:disable|checkOnly|informational|set(?:Disable|CheckOnly|Informational))\s*(?:\+=|=|\(|\.add(?:All)?\s*\()/u,
  },
  { directive: "compiler-nowarn", pattern: /-nowarn\b|-Xsuppress-warning|-Xwarning-level/u },
];

const BUILD_VALUE_GUARDS: readonly ValueGuard[] = [
  { name: "(?:is)?[Ii]gnoreFailures", setter: "(?:Is)?IgnoreFailures", allowed: "false" },
  { name: "allWarningsAsErrors", setter: "AllWarningsAsErrors", allowed: "true" },
  { name: "suppressWarnings", setter: "SuppressWarnings", allowed: "false" },
  { name: "ignoreWarnings", setter: "IgnoreWarnings", allowed: "false" },
  { name: "warningsAsErrors", setter: "WarningsAsErrors", allowed: "true" },
  { name: "abortOnError", setter: "AbortOnError", allowed: "true" },
  { name: "checkAllWarnings", setter: "CheckAllWarnings", allowed: "true" },
  { name: "checkTestSources", setter: "CheckTestSources", allowed: "true" },
  { name: "ignoreTestSources", setter: "IgnoreTestSources", allowed: "false" },
  { name: "allRules", setter: "AllRules", allowed: "true" },
  { name: "buildUponDefaultConfig", setter: "BuildUponDefaultConfig", allowed: "true" },
  { name: "disableDefaultRuleSets", setter: "DisableDefaultRuleSets", allowed: "false" },
  { name: "failOnSeverity", setter: "FailOnSeverity", allowed: "(?:[\\w.]*FailOnSeverity\\.)?Info" },
  {
    name: "ignored(?:Variants|BuildTypes|Flavors)",
    setter: "Ignored(?:Variants|BuildTypes|Flavors)",
    allowed: "emptyList\\(\\)",
  },
  { name: "baseline(?:File)?", setter: "Baseline(?:File)?", allowed: "null(?:\\s+as\\s+[\\w.]+\\?)?" },
];

const EDITORCONFIG_RULES: readonly Rule[] = [
  { directive: "ktlint-editorconfig-disabled", pattern: /^\s*ktlint_[\w-]+\s*=\s*disabled\b/u },
];

const XCODE_RULES: readonly Rule[] = [
  {
    directive: "SWIFT_TREAT_WARNINGS_AS_ERRORS",
    pattern: /\bSWIFT_TREAT_WARNINGS_AS_ERRORS\s*=(?!\s*"?YES"?\s*(?:;|$|\/\/))/u,
  },
  { directive: "GCC_TREAT_WARNINGS_AS_ERRORS", pattern: /\bGCC_TREAT_WARNINGS_AS_ERRORS\s*=\s*"?NO\b/u },
  {
    directive: "inhibit-warnings",
    pattern: /\b(?:SWIFT_SUPPRESS_WARNINGS|GCC_WARN_INHIBIT_ALL_WARNINGS)\s*=\s*"?YES\b|-suppress-warnings\b/u,
  },
];

function valueGuardFindings(line: string): string[] {
  const directives: string[] = [];

  for (const guard of BUILD_VALUE_GUARDS) {
    const mention = new RegExp(`\\b(${guard.name})\\b`, "gu");
    const accepted = new RegExp(
      `^\\s*(?:=\\s*${guard.allowed}(?![\\w.(])|\\.set\\(\\s*${guard.allowed}\\s*\\)|\\.disallowChanges\\(\\s*\\)|\\.(?:orNull|isPresent)(?![\\w(])|\\.get\\(\\s*\\))`,
      "u",
    );

    const setter = new RegExp(`\\b(set${guard.setter})\\s*\\(`, "gu");
    const acceptedSetter = new RegExp(`^\\s*${guard.allowed}\\s*\\)`, "u");
    let found = false;

    for (const match of line.matchAll(mention)) {
      const rest = line.slice((match.index ?? 0) + match[0].length);

      if (!accepted.test(rest)) {
        directives.push(match[1] ?? guard.name);
        found = true;
        break;
      }
    }
    if (found) continue;
    for (const match of line.matchAll(setter)) {
      const rest = line.slice((match.index ?? 0) + match[0].length);

      if (!acceptedSetter.test(rest)) {
        directives.push(match[1] ?? guard.setter);
        break;
      }
    }
  }

  return directives;
}

/**
 * 0-based indexes of the lines holding `Suppress` (or SuppressWarnings /
 * SuppressLint) inside a bracketed annotation list - `@[A B]`,
 * `@file:[A B]` - wherever it sits in the list and across lines.
 */
function bracketSuppressLines(content: string): Set<number> {
  const lines = new Set<number>();
  const list = /@\s*(?:`?[a-z]+`?\s*:\s*)?\[([^\]]*)\]/gu;
  const suppress = /(?:^|[^\w`])`?Suppress(?:Warnings|Lint)?\b/gu;

  for (const match of content.matchAll(list)) {
    const inner = match[1] ?? "";
    const innerStart = (match.index ?? 0) + match[0].indexOf("[") + 1;

    for (const hit of inner.matchAll(suppress)) {
      const offset = innerStart + (hit.index ?? 0) + hit[0].indexOf("S");

      lines.add(content.slice(0, offset).split("\n").length - 1);
    }
  }

  return lines;
}

function isCommentLine(line: string): boolean {
  return /^\s*(?:\/\/|\/?\*)/u.test(line);
}

function isBuildFile(file: string): boolean {
  return /\.(?:kts|gradle)$/u.test(file) || /(?:^|\/)(?:build-logic|buildSrc)\/.*\.kt$/u.test(file);
}

function rulesFor(file: string): readonly Rule[] {
  const base = path.posix.basename(file);
  const rules: Rule[] = [];

  if (/\.(?:kt|kts|java|gradle)$/u.test(file)) rules.push(...KOTLIN_RULES);
  if (isBuildFile(file)) rules.push(...BUILD_RULES);
  if (file.endsWith(".swift")) rules.push(...SWIFT_RULES);
  if (file.endsWith(".swift") && isSwiftTestSource(file)) rules.push(...SWIFT_TEST_RULES);
  if (file.endsWith(".xml")) rules.push(...XML_RULES);
  if (base === ".editorconfig") rules.push(...EDITORCONFIG_RULES);
  if (/\.(?:xcconfig|pbxproj)$/u.test(file)) rules.push(...XCODE_RULES);

  return rules;
}

/** Findings about a file's mere presence: baselines and nested lint configs. */
function fileFindings(file: string): Finding[] {
  const base = path.posix.basename(file);

  if (/baseline[^/]*\.xml$/iu.test(base)) {
    return [{ file, line: 0, directive: "baseline-file", code: file }];
  }
  if (base === ".swiftlint.yml" || base === ".swiftlint.yaml") {
    return [{ file, line: 0, directive: "swiftlint-config", code: file }];
  }

  return [];
}

/** Every finding in one file's content. */
export function scanContent(file: string, content: string): Finding[] {
  const findings: Finding[] = [...fileFindings(file)];
  const rules = rulesFor(file);
  const buildFile = isBuildFile(file);

  if (rules.length === 0 && !buildFile) return findings;

  const bracketed = /\.(?:kt|kts|java|gradle)$/u.test(file) ? bracketSuppressLines(content) : new Set<number>();

  content.split(/\r?\n/u).forEach((line, index) => {
    const code = line.trim();
    const directives = new Set<string>();

    if (bracketed.has(index)) directives.add("@Suppress");
    for (const rule of rules) {
      if (rule.pattern.test(line)) directives.add(rule.directive);
    }
    if (buildFile && !isCommentLine(line)) {
      for (const directive of valueGuardFindings(line)) directives.add(directive);
    }
    for (const directive of directives) {
      findings.push({ file, line: index + 1, directive, code });
    }
  });

  return findings;
}

export function keyOf(finding: Finding): string {
  return `${finding.file} :: ${finding.directive} :: ${finding.code}`;
}

export function parseRegistry(text: string): string[] {
  return text
    .split(/\r?\n/u)
    .map((line) => line.trim())
    .filter((line) => line !== "" && !line.startsWith("#"));
}

function isScanned(file: string): boolean {
  if (EXCLUDED_PREFIXES.some((prefix) => file.startsWith(prefix))) return false;

  return !file.endsWith(".md");
}

function listFiles(root: string): string[] {
  const result = spawnSync("git", ["ls-files", "-z", "-co", "--exclude-standard"], {
    cwd: root,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });

  if (result.status !== 0) {
    throw new Error(`git ls-files failed: ${result.stderr}`);
  }

  return [...new Set(result.stdout.split("\0").filter((file) => file !== ""))];
}

function main(): number {
  const top = spawnSync("git", ["rev-parse", "--show-toplevel"], { encoding: "utf8" });

  if (top.status !== 0) {
    console.error("suppressions: not inside a git repository");

    return 1;
  }

  const root = top.stdout.trim();
  const findings: Finding[] = [];

  for (const file of listFiles(root).filter(isScanned)) {
    const full = path.join(root, file);

    // Listed but deleted in the working tree, or not a regular file.
    if (!existsSync(full)) continue;

    let content: string;

    try {
      content = readFileSync(full, "utf8");
    } catch {
      continue;
    }

    findings.push(...scanContent(file, content));
  }

  const registryPath = path.join(root, "quality/suppressions.allow");
  const registry = new Set(existsSync(registryPath) ? parseRegistry(readFileSync(registryPath, "utf8")) : []);
  const found = new Set(findings.map(keyOf));
  const unregistered = findings.filter((finding) => !registry.has(keyOf(finding)));
  const stale = [...registry].filter((key) => !found.has(key));

  for (const finding of unregistered) {
    const where = finding.line === 0 ? finding.file : `${finding.file}:${finding.line}`;

    console.log(`unregistered suppression [${finding.directive}]: ${where}: ${finding.code}`);
    console.log(`  register it as '${keyOf(finding)}' in quality/suppressions.allow (with a reason) or, better, fix the finding`);
  }
  for (const key of stale) {
    console.log(`stale registry entry: ${key} (no such finding in the tree)`);
  }

  if (unregistered.length > 0 || stale.length > 0) {
    console.log(`suppressions: ${unregistered.length} unregistered directive(s), ${stale.length} stale registry entr(y/ies)`);

    return 1;
  }

  console.log(`suppressions: ${findings.length} directive(s), all registered`);

  return 0;
}

if (process.argv[1] !== undefined && path.resolve(process.argv[1]) === import.meta.filename) {
  process.exitCode = main();
}
