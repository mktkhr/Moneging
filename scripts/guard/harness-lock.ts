/**
 * Whether the harness's protected paths (quality/protected-paths.txt) are
 * open to editing right now.
 *
 * The harness can be UNLOCKED for a bounded iteration window so the human
 * can ask a session to change the harness itself without an out-of-band
 * script for every small edit. quality/harness-lock.txt names the last date
 * that window is open - but the state that governs a session is what that
 * file said at refs/harness/approved (the last harness state the human
 * reviewed and approved with `make harness-approve`), never the working
 * tree. An edit sitting uncommitted, or committed but not yet approved, has
 * no effect until the human commits it (with MONEGING_ALLOW_HARNESS_CHANGE=1)
 * and runs `make harness-approve`; only that moves the ref. Everything else
 * fails closed: no such ref, no file at that ref, a line that does not
 * parse, or a date that has passed all mean LOCKED. There is no scope here
 * that widens the window itself - see protected-entries.ts's
 * ALWAYS_PROTECTED for the paths that stay protected even while unlocked
 * (this file and quality/harness-lock.txt are two of them).
 *
 * Both the tool-policy hook (TypeScript) and protected-paths.sh (POSIX sh,
 * run again at commit time) need this decision. The parsing lives here,
 * once; protected-paths.sh gets it by invoking this file as a CLI (see
 * main() below) rather than re-implementing the date logic in shell.
 */
import { execFileSync } from "node:child_process";
import path from "node:path";

export interface LockState {
  readonly unlocked: boolean;
  /** The date named by the file, even when it has already passed; null when the file is missing or unparsable. */
  readonly until: string | null;
  readonly reason: "unlocked" | "missing" | "malformed" | "expired";
}

const LINE = /^unlocked-until:\s*(\d{4}-\d{2}-\d{2})\s*$/u;

/** Whether `date` (YYYY-MM-DD) names a real calendar date, not just a shape. */
function isValidDate(date: string): boolean {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/u.exec(date);

  if (match === null) return false;

  const [, y, m, d] = match;
  const year = Number(y);
  const month = Number(m);
  const day = Number(d);
  const parsed = new Date(year, month - 1, day);

  return parsed.getFullYear() === year && parsed.getMonth() === month - 1 && parsed.getDate() === day;
}

/** Parses harness-lock.txt content into the date it names, or null when no line parses. */
export function parseUnlockDate(text: string): string | null {
  for (const rawLine of text.split("\n")) {
    const line = rawLine.trim();

    if (line === "" || line.startsWith("#")) continue;

    const match = LINE.exec(line);

    if (match !== null && isValidDate(match[1] ?? "")) return match[1] ?? null;

    return null; // the first non-comment line is malformed: fail closed rather than skip it
  }

  return null;
}

/** Today's date as YYYY-MM-DD in local time, so it lines up with a human editing the file by hand. */
export function localDateString(now: Date = new Date()): string {
  const year = String(now.getFullYear()).padStart(4, "0");
  const month = String(now.getMonth() + 1).padStart(2, "0");
  const day = String(now.getDate()).padStart(2, "0");

  return `${year}-${month}-${day}`;
}

/**
 * The lock decision for a given file content and today's date, both
 * injectable so tests never touch the real clock or filesystem.
 * Lexicographic comparison of two fixed-width YYYY-MM-DD strings is a valid
 * date comparison, and it sidesteps the timezone traps of parsing the date
 * with `new Date(string)`.
 */
export function evaluate(text: string | null, today: string): LockState {
  if (text === null) return { unlocked: false, until: null, reason: "missing" };

  const until = parseUnlockDate(text);

  if (until === null) return { unlocked: false, until: null, reason: "malformed" };
  if (today <= until) return { unlocked: true, until, reason: "unlocked" };

  return { unlocked: false, until, reason: "expired" };
}

const APPROVED_REF = "refs/harness/approved";
const LOCK_FILE_PATH = "quality/harness-lock.txt";

/** A source of a file's committed content at a git ref: `(root, ref, path) => content, or null`. Swappable in tests for a fast in-memory stand-in. */
export type GitRefReader = (root: string, ref: string, filePath: string) => string | null;

/**
 * Reads a file's content at a git ref via `git show <ref>:<path>`, run from
 * `root`. Returns null - never throws - when git is unavailable, `root` is
 * not a git working tree, the ref does not exist, or the file does not
 * exist at that ref: every one of those means LOCKED to `evaluate()`.
 */
export function readGitRefFile(root: string, ref: string, filePath: string): string | null {
  try {
    return execFileSync("git", ["show", `${ref}:${filePath}`], {
      cwd: root,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    });
  } catch {
    return null;
  }
}

/**
 * The harness lock state as last approved by the human, not the working
 * tree - see the file-level comment above for why. `today` and `reader` are
 * both injectable: tests supply a fast in-memory `reader` for pure unit
 * tests of the date logic, or exercise `readGitRefFile` itself against a
 * real temporary git repository for an end-to-end check.
 */
export function readLockState(
  root: string,
  today: string = localDateString(),
  reader: GitRefReader = readGitRefFile,
): LockState {
  const text = reader(root, APPROVED_REF, LOCK_FILE_PATH);

  return evaluate(text, today);
}

/**
 * CLI: prints one line to stdout so protected-paths.sh can read the state
 * without re-parsing dates itself - `unlocked <date>` or `locked <reason>`.
 * Exit code 0 when unlocked, 1 when locked.
 *
 * Takes the repository root as its first argument, in preference to
 * $CLAUDE_PROJECT_DIR: a caller such as protected-paths.sh is invoked by
 * git (a hook, `make`, or a human's own shell) rather than by a live Claude
 * Code session, determines the true root itself (`git rev-parse
 * --show-toplevel`), and must not defer to a Claude-session variable that
 * may be stale, unset, or unrelated to the repository being checked.
 */
function main(): number {
  const argRoot = process.argv[2];
  const root = argRoot !== undefined ? argRoot : process.env["CLAUDE_PROJECT_DIR"] ?? process.cwd();
  const state = readLockState(root);

  if (state.unlocked) {
    process.stdout.write(`unlocked ${state.until}\n`);

    return 0;
  }

  process.stdout.write(`locked ${state.reason}${state.until === null ? "" : ` ${state.until}`}\n`);

  return 1;
}

if (process.argv[1] !== undefined && path.resolve(process.argv[1]) === import.meta.filename) {
  process.exitCode = main();
}
