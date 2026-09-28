/**
 * Toolchain guard: fails when the `node` or `java` actually running does not
 * match the versions pinned in mise.toml.
 *
 * The harness's guard scripts and tests run as native TypeScript
 * (`node --test`, `node scripts/guard/*.ts`), which needs Node >= 24; the
 * KMP client builds with the JDK named by
 * clients/kmp/gradle/gradle-daemon-jvm.properties. mise.toml pins one exact
 * version of each so every session and the human's own shell run the same
 * toolchain. Claude Code's hooks run `node` as found on PATH at the time the
 * hook fires, not through the human's own zsh (where mise's shims are
 * activated) - so the two can drift silently. This guard compares major
 * versions only: mise.toml pins an exact patch for reproducibility, but a
 * patch-level difference does not change what the harness needs.
 */
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import path from "node:path";

export interface Mismatch {
  readonly tool: string;
  readonly pinned: string;
  readonly pinnedMajor: number;
  /** null when the tool could not be found or its version could not be read. */
  readonly runningMajor: number | null;
}

/**
 * Extracts the version string pinned for `tool` in mise.toml's [tools]
 * table, e.g. `node = "26.5.0"` -> "26.5.0". Accepts either TOML string
 * style (`"..."` or `'...'`) and an optional trailing `# comment`.
 */
export function pinnedVersion(miseToml: string, tool: string): string | null {
  const re = new RegExp(`^${tool}\\s*=\\s*(?:"([^"]*)"|'([^']*)')\\s*(?:#.*)?$`, "mu");
  const match = re.exec(miseToml);

  if (match === null) return null;

  return match[1] ?? match[2] ?? null;
}

/**
 * The leading major version number of a mise version string: the first run
 * of digits that starts the string or immediately follows a `-`.
 * "26.5.0" -> 26; "temurin-21.0.10+7.0.LTS" -> 21 (mise's `vendor-version`
 * shorthand for the java plugin - the vendor name itself is not a version
 * number, so the *first* hyphen-led digit run is taken, not whatever follows
 * the last `-`, which would misread something like "26.5.0-rc1").
 */
export function majorOf(version: string): number | null {
  const match = /(?:^|-)(\d+)/u.exec(version);

  return match ? Number(match[1]) : null;
}

/**
 * Parses the major version out of `java -version`'s banner (written to
 * stderr, e.g. `openjdk version "21.0.10" ...`). Handles the legacy
 * "1.MAJOR.MINOR_UPDATE" scheme Java 8 and earlier used - `1.8.0_392` is
 * major 8, not 1.
 */
export function parseJavaVersionOutput(text: string): number | null {
  const match = /version "(\d+)(?:\.(\d+))?/u.exec(text);

  if (match === null) return null;

  const first = Number(match[1]);

  if (first === 1 && match[2] !== undefined) return Number(match[2]);

  return first;
}

/**
 * Compares one tool's running major version against mise.toml's pin.
 * Returns null when they agree, or when the tool has no pin in mise.toml, or
 * when the pin does not parse - validating mise.toml's own syntax is not
 * this guard's job.
 */
export function check(miseToml: string, tool: string, runningMajor: number | null): Mismatch | null {
  const pinned = pinnedVersion(miseToml, tool);

  if (pinned === null) return null;

  const pinnedMajor = majorOf(pinned);

  if (pinnedMajor === null || pinnedMajor === runningMajor) return null;

  return { tool, pinned, pinnedMajor, runningMajor };
}

function nodeMajor(): number | null {
  const match = /^v?(\d+)/u.exec(process.version);

  return match ? Number(match[1]) : null;
}

function javaMajor(): number | null {
  // java -version writes its banner to stderr and exits 0; spawnSync (unlike
  // execFileSync, which only returns stdout and throws on a non-zero exit)
  // hands back both streams regardless of exit status, and `error` is set
  // instead of throwing when java itself cannot be found.
  const result = spawnSync("java", ["-version"], { encoding: "utf8" });

  if (result.error) return null;

  return parseJavaVersionOutput(`${result.stdout}${result.stderr}`);
}

function message(mismatch: Mismatch): string {
  const running = mismatch.runningMajor === null ? "not found on PATH" : `major ${mismatch.runningMajor}`;

  return (
    `guard-toolchain: ${mismatch.tool} is ${running}, but mise.toml pins ${mismatch.tool} = "${mismatch.pinned}" ` +
    `(major ${mismatch.pinnedMajor}). Run \`mise install\` (\`make tools\`).`
  );
}

/**
 * The repository root, derived from this file's own location
 * (scripts/guard/toolchain.ts is always two directories below it) rather
 * than $CLAUDE_PROJECT_DIR or the process's cwd: this guard is invoked by
 * `make` (from wherever `make` itself was invoked) as well as by a live
 * Claude Code session, and must find the same mise.toml either way.
 */
function repoRoot(): string {
  return path.resolve(import.meta.dirname, "..", "..");
}

function main(): number {
  try {
    // An explicit root argument (tests only - the Makefile and the
    // SessionStart/PreToolUse hooks never pass one) takes precedence over
    // the derived one, the same convention the other guard CLIs use.
    const root = process.argv[2] ?? repoRoot();
    const miseToml = readFileSync(path.join(root, "mise.toml"), "utf8");

    const problems: string[] = [];

    // A missing node/java pin is itself the problem this guard exists to
    // catch, not something to pass over quietly: reusable `check()` returns
    // null for "no pin" because scripts/guard/session-start.ts also calls it
    // and must stay silent then, but this CLI's whole job is to enforce that
    // node and java are pinned and matched.
    for (const [tool, runningMajor] of [
      ["node", nodeMajor()],
      ["java", javaMajor()],
    ] as const) {
      if (pinnedVersion(miseToml, tool) === null) {
        problems.push(`guard-toolchain: mise.toml has no ${tool} pin under [tools]; add one.`);
        continue;
      }

      const mismatch = check(miseToml, tool, runningMajor);

      if (mismatch !== null) problems.push(message(mismatch));
    }

    if (problems.length === 0) {
      process.stdout.write("guard-toolchain: node and java match mise.toml\n");

      return 0;
    }

    for (const problem of problems) process.stderr.write(`${problem}\n`);

    return 1;
  } catch (error) {
    const messageText = error instanceof Error ? error.message : String(error);

    process.stderr.write(`guard-toolchain: ${messageText}; refusing\n`);

    return 1;
  }
}

if (process.argv[1] !== undefined && path.resolve(process.argv[1]) === import.meta.filename) {
  process.exitCode = main();
}
