/**
 * The registry of protected paths (quality/protected-paths.txt) and the one
 * question every guard asks of it: is a path protected. ALWAYS_PROTECTED is
 * refused alongside it and is not committed content.
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
 * Refused to every session, path tools and Bash writes alike: `.git` and the
 * human's own local Claude settings (never committed) are never a session's
 * to touch, not even through an apply script's review.
 */
export const ALWAYS_PROTECTED: readonly string[] = [".git", ".claude/settings.local.json"];
