/**
 * Claude Code SessionStart hook: a one-line reminder of the harness lock
 * state, printed to stdout so it lands in Claude's context at the start of
 * the turn. Read-only; it never changes the lock, only reports it (see
 * scripts/guard/harness-lock.ts for what LOCKED/UNLOCKED mean).
 *
 * Also warns, in one line, when this session's own `node` (the one Claude
 * Code's hooks run from PATH, not necessarily the one mise activates in the
 * human's own zsh - see scripts/guard/toolchain.ts) does not match
 * mise.toml's pinned major, older or newer, same as `make guard-toolchain`.
 * This is best-effort, not a substitute for that guard: a `node` too old to
 * even run this file's native-TypeScript syntax fails before ever reaching
 * this warning, so it only catches a mismatch mild enough for the hook to
 * still execute.
 */
import { readFileSync } from "node:fs";
import path from "node:path";

import { readLockState } from "./harness-lock.ts";
import { majorOf, pinnedVersion } from "./toolchain.ts";

/**
 * One line when `runningVersion` (process.version's format, e.g. "v22.1.0")
 * has a different major version than mise.toml's node pin, older or newer;
 * null when it matches, or when either version cannot be read - this hook
 * must not fail the session over a missing or unparsable mise.toml.
 */
export function nodeVersionWarning(miseToml: string | null, runningVersion: string): string | null {
  if (miseToml === null) return null;

  const pinned = pinnedVersion(miseToml, "node");

  if (pinned === null) return null;

  const pinnedMajor = majorOf(pinned);
  const runningMajor = majorOf(runningVersion.replace(/^v/u, ""));

  if (pinnedMajor === null || runningMajor === null || runningMajor === pinnedMajor) return null;

  return (
    `node ${runningVersion} does not match mise.toml's pin (node ${pinned}); Claude Code hooks run ` +
    "node from PATH, not through mise - run `mise install` (`make tools`) or check your shell's PATH."
  );
}

function readMiseToml(root: string): string | null {
  try {
    return readFileSync(path.join(root, "mise.toml"), "utf8");
  } catch {
    return null;
  }
}

function main(): number {
  const root = process.env["CLAUDE_PROJECT_DIR"] ?? process.cwd();
  const state = readLockState(root);

  const nodeWarning = nodeVersionWarning(readMiseToml(root), process.version);

  if (nodeWarning !== null) process.stdout.write(`${nodeWarning}\n`);

  const howToChange =
    "to change it, the human edits quality/harness-lock.txt, commits it with " +
    "MONEGING_ALLOW_HARNESS_CHANGE=1 set, then runs `make harness-approve`";

  if (state.unlocked) {
    process.stdout.write(
      `harness lock: UNLOCKED until ${state.until} (from refs/harness/approved; auto-locks once ` +
        `today passes that date) - ${howToChange}\n`,
    );

    return 0;
  }

  if (state.reason === "expired") {
    process.stdout.write(
      `harness lock: LOCKED (unlocked-until ${state.until}, from refs/harness/approved, has ` +
        `passed) - ${howToChange}\n`,
    );

    return 0;
  }

  process.stdout.write(
    `harness lock: LOCKED (${state.reason}: refs/harness/approved has no readable ` +
      `quality/harness-lock.txt naming a valid date) - ${howToChange}\n`,
  );

  return 0;
}

if (process.argv[1] !== undefined && path.resolve(process.argv[1]) === import.meta.filename) {
  process.exitCode = main();
}
