/**
 * Claude Code SessionStart hook: a one-line reminder of the harness lock
 * state, printed to stdout so it lands in Claude's context at the start of
 * the turn. Read-only; it never changes the lock, only reports it (see
 * scripts/guard/harness-lock.ts for what LOCKED/UNLOCKED mean).
 */
import path from "node:path";

import { readLockState } from "./harness-lock.ts";

function main(): number {
  const root = process.env["CLAUDE_PROJECT_DIR"] ?? process.cwd();
  const state = readLockState(root);

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
