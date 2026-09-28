/**
 * The Bash half of the Repository Harness's tool policy: which commands are
 * refused outright, and which write near a path the caller may not write.
 * scripts/guard/tool-policy.ts is the entry point; this module holds the
 * command-text rules it applies to Bash calls. ALWAYS_REFUSED and the
 * always-protected paths bind every caller; which other paths a caller may
 * write, and whether it may commit them, depends on its role
 * (scripts/guard/roles.ts).
 */
import { execFileSync } from "node:child_process";
import path from "node:path";

import { ALWAYS_PROTECTED, isProtected } from "./protected-entries.ts";
import { ACCEPTANCE_DIR, PRODUCT_DIRS, type Role } from "./roles.ts";

/** Refused unconditionally, to every caller. */
const ALWAYS_REFUSED: readonly (readonly [RegExp, string])[] = [
  // Matches the full word and any abbreviation git would accept
  // (--no-verify, --no-verif, --no-ver, ...), not just the exact spelling.
  [/--no-ver\w*/u, "hooks are part of the harness; fix what they report"],
  [/\bgit\b[^;&|]*\bcommit\b[^;&|]*\s-[a-zA-Z]*n[a-zA-Z]*\b/u, "`git commit -n` skips the hooks"],
  [/core\.hookspath/iu, "the hooks path is set by `make hooks`"],
  [
    /\bgit\b[^;&|]*\bpush\b[^;&|]*\s(--force|--force-with-lease|-f)\b/u,
    "published history is not rewritten",
  ],
  // Also catches a force push spelled as a refspec (`git push origin +main`)
  // rather than a `--force` flag.
  [/\bpush\b[^;&|]*\s\+\S/u, "published history is not rewritten"],
  [
    /\bgit\b[^;&|]*\badd\b[^;&|]*\s(--force|-[a-zA-Z]*f[a-zA-Z]*)\b/u,
    "-f/--force stages what .gitignore denies by default (including docs/superpowers); nothing here forces that",
  ],
  [
    /\bgit\s+update-index\b[^;&|]*(--skip-worktree|--assume-unchanged)\b/u,
    "hiding changes from git hides them from the harness",
  ],
  [
    /\bgit\s+(apply|am)\b|(^|[;&|]\s*)patch\s/u,
    "patches can change protected paths the policy cannot see; make the change with Edit or Write",
  ],
];

/**
 * Refused only when the command would also mutate: a command merely reading
 * (`cat .cache/stop-gate/judged`, ...) changes nothing and is allowed. The
 * optional third element adds a verb that counts as mutating for that rule
 * alone.
 */
const MUTATION_GATED_REFUSED: readonly (readonly [RegExp, string, RegExp?])[] = [
  [/\.cache\/stop-gate/u, "only the Stop hook records a verified tree"],
];

/** The verbs whose every token (not just a redirect target) is a write candidate. */
const WRITE_VERBS =
  /(^|[\s;&|])(sed\s+-i|perl\s+-\S*i|tee|cp|mv|rm|chmod|truncate|ln|install|dd|rsync|touch)\b|\bgit\s+(checkout|restore|rm|mv)\b/u;

/** Runs a file rather than merely reading it: an interpreter, `source`/`.`, or `./…`. */
const EXEC_VERBS = /(^|[\s;&|])(sh|bash|source|node|env)\b|(^|[\s;&|])\.(?=\s)|(^|[\s;&|])\.\//u;

/** Stream duplications and null sinks: not writes to a file at all. */
const STREAM_NOISE = /\d*>&\d+|&>\s*\/dev\/null|\d*>>?\s*\/dev\/null/gu;

/** A redirect and the token it writes to. */
const REDIRECT = /(?:\d*>>?|&>>?)\s*(\S+)/gu;

/** Whether a redirect (not a stream duplication or a null sink) is present. */
const HAS_REDIRECT = /(?:\d*>>?|&>>?)\s*\S+/u;

/** A `git commit` invocation, and whether it also stages tracked changes (`-a`/`--all`). */
const GIT_COMMIT = /\bgit\b[^;&|]*\bcommit\b/u;
const GIT_COMMIT_ALL = /\bgit\b[^;&|]*\bcommit\b[^;&|]*(\s--all\b|\s-[a-zA-Z]*a[a-zA-Z]*\b)/u;

/** Whether the command writes a file, or runs one, instead of only reading it. */
function mutatesFilesystem(command: string): boolean {
  if (WRITE_VERBS.test(command)) return true;
  if (HAS_REDIRECT.test(command.replaceAll(STREAM_NOISE, ""))) return true;

  return EXEC_VERBS.test(command);
}

/** Splits a command into its `;`/`&&`/`||`/`|` segments and drops each segment's verb token. */
function segmentTokensWithoutVerb(command: string): string[] {
  return command.split(/&&|\|\||[;|]/u).flatMap((segment) =>
    segment
      .split(/[\s<>()]+/u)
      .filter((token) => token !== "")
      .slice(1),
  );
}

/** Strips a token's surrounding quotes. */
function unquote(token: string): string {
  return token.replaceAll(/^['"]|['"]$/gu, "");
}

/** A command token resolved to a repository-relative path, against `cwd` when given. */
function resolveToken(token: string, root: string, cwd: string | undefined): string {
  const base = cwd === undefined ? root : path.resolve(root, cwd);

  return path.relative(root, path.resolve(base, token)).split(path.sep).join("/");
}

/** Whether a repository-relative path lies inside the repository. */
function insideRepository(resolved: string): boolean {
  return resolved !== ".." && !resolved.startsWith("../") && !path.isAbsolute(resolved);
}

/**
 * Whether `role` may not write the repository-relative path `resolved`.
 * - every caller: the always-protected paths
 * - main: nothing else (the human approves its harness changes in conversation)
 * - restricted (implementers, any unnamed subagent): the harness and acceptance/
 * - acceptance-writer: the harness and the product source trees
 * - reviewer: anything inside the repository
 */
export function isBannedTarget(resolved: string, entries: readonly string[], role: Role): boolean {
  if (isProtected(resolved, ALWAYS_PROTECTED)) return true;

  switch (role) {
    case "main":
      return false;
    case "reviewer":
      return insideRepository(resolved);
    case "acceptance-writer":
      return isProtected(resolved, entries) || isProtected(resolved, PRODUCT_DIRS);
    case "restricted":
      return isProtected(resolved, entries) || isProtected(resolved, [ACCEPTANCE_DIR]);
  }
}

/** The paths a commit would record: `(root, includeUnstaged) => repository-relative paths`. */
export type ChangeLister = (root: string, includeUnstaged: boolean) => string[];

/** Lists the staged paths (plus unstaged tracked changes for `commit -a`) with git. */
export function listCommitPaths(root: string, includeUnstaged: boolean): string[] {
  const run = (args: string[]): string[] =>
    execFileSync("git", args, { cwd: root, encoding: "utf8" })
      .split("\n")
      .filter((line) => line !== "");
  const staged = run(["diff", "--cached", "--name-only"]);

  return includeUnstaged ? [...staged, ...run(["diff", "--name-only"])] : staged;
}

/**
 * The reason a commit by `role` is refused, or null. Backstops the write
 * rules: whatever reached the index by a route the command-text rules did
 * not see, a restricted caller still cannot commit a path it may not write.
 */
function commitViolation(
  command: string,
  entries: readonly string[],
  root: string,
  role: Role,
  listChanged: ChangeLister,
): string | null {
  if (role === "main" || !GIT_COMMIT.test(command)) return null;
  if (role === "reviewer") return "a reviewer reports findings; it does not commit";

  const banned = listChanged(root, GIT_COMMIT_ALL.test(command)).find((file) =>
    isBannedTarget(file, entries, role),
  );

  return banned === undefined ? null : `the commit would include ${banned}, which this role may not change`;
}

/** The reason a shell command is refused, or null. */
export function bannedCommand(
  command: string,
  entries: readonly string[],
  root: string,
  cwd?: string,
  role: Role = "restricted",
  listChanged: ChangeLister = listCommitPaths,
): string | null {
  for (const [pattern, reason] of ALWAYS_REFUSED) {
    if (pattern.test(command)) return reason;
  }

  for (const [pattern, reason, extraMutation] of MUTATION_GATED_REFUSED) {
    if (!pattern.test(command)) continue;
    if (mutatesFilesystem(command) || (extraMutation?.test(command) ?? false)) return reason;
  }

  const withoutNoise = command.replaceAll(STREAM_NOISE, "");
  const redirectTargets = [...withoutNoise.matchAll(REDIRECT)].map((match) =>
    unquote(match[1] ?? ""),
  );
  const redirected = redirectTargets
    .map((token) => resolveToken(token, root, cwd))
    .find((resolved) => isBannedTarget(resolved, entries, role));

  if (redirected !== undefined) return `the command writes near the protected path ${redirected}`;

  if (WRITE_VERBS.test(command)) {
    const touched = segmentTokensWithoutVerb(command)
      .map((token) => unquote(token))
      .map((token) => token.replace(/^[a-z]+=/u, ""))
      .filter((token) => token !== "" && !token.startsWith("-"))
      .map((token) => resolveToken(token, root, cwd))
      .find((resolved) => isBannedTarget(resolved, entries, role));

    if (touched !== undefined) return `the command writes near the protected path ${touched}`;
  }

  return commitViolation(command, entries, root, role, listChanged);
}
