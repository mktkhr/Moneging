/**
 * The registry of protected paths (quality/protected-paths.txt) and the one
 * question every guard asks of it: is a path protected. Which callers the
 * registry binds is decided by role (scripts/guard/roles.ts);
 * ALWAYS_PROTECTED binds every caller, the main session included.
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
 * Refused to every caller, path tools and Bash writes alike: `.git` and the
 * human's own local Claude settings (never committed) are never a session's
 * to touch.
 */
export const ALWAYS_PROTECTED: readonly string[] = [".git", ".claude/settings.local.json"];
