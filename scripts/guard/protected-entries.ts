/**
 * The registry of protected paths (quality/protected-paths.txt) and the one
 * question every guard asks of it: is a path protected. Most protected
 * paths open up while the harness is UNLOCKED (scripts/guard/harness-lock.ts);
 * ALWAYS_PROTECTED never does.
 */
import path from "node:path";

/** Entries of quality/protected-paths.txt. */
export function protectedEntries(text: string): string[] {
  return text
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line !== "" && !line.startsWith("#"));
}

/** Whether a repository-relative path is, or is under, a protected entry. */
export function isProtected(relative: string, entries: readonly string[]): boolean {
  const clean = path.posix.normalize(relative.split(path.sep).join("/")).replace(/^\.\//u, "");

  return entries.some((entry) => clean === entry || clean.startsWith(`${entry}/`));
}

/**
 * Refused, path tools and Bash writes alike, always - locked or unlocked.
 * `.git` and the human's own local Claude settings (never committed) are
 * never a session's to touch. quality/harness-lock.txt and its parser
 * (scripts/guard/harness-lock.ts) are the lock mechanism's own integrity:
 * without protecting those two, an unlocked session could push its own
 * expiry forward or rewrite the code that reads it, making the lock
 * meaningless the moment it was ever open. This is the one TypeScript source
 * of truth for that pair - harness-lock.ts does not also export it, so
 * there is only one list to keep in sync with scripts/guard/protected-paths.sh's
 * independent, hardcoded shell copy (see there for why that copy exists too).
 * Kept to this minimal set; everything else in quality/protected-paths.txt
 * is free to iterate on while unlocked.
 */
export const ALWAYS_PROTECTED: readonly string[] = [
  ".git",
  ".claude/settings.local.json",
  "quality/harness-lock.txt",
  "scripts/guard/harness-lock.ts",
];
