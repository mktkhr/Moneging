/**
 * The Bash half of the Repository Harness's tool policy: which commands are
 * refused outright, and which write near a path the caller may not write.
 * scripts/guard/tool-policy.ts is the entry point; this module holds the
 * command-text rules it applies to Bash calls. ALWAYS_REFUSED and the
 * always-protected paths bind every caller; which other paths a caller may
 * write, and whether it may commit, depends on its role
 * (scripts/guard/roles.ts).
 *
 * Text rules stop habits and accidents, not deliberate evasion (an
 * interpreter one-liner writing a file is not caught). The commit backstop
 * below is the second line for subagents: whatever reached the working tree
 * by a route the text rules missed, a subagent still cannot commit it.
 */
import { execFileSync } from "node:child_process";
import path from "node:path";

import { ALWAYS_PROTECTED, isProtected } from "./protected-entries.ts";
import { ACCEPTANCE_DIR, type Role } from "./roles.ts";

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

/** A git subcommand, after any global options (`git -C dir -c k=v <sub>`). */
function gitSubcommand(names: string): RegExp {
  return new RegExp(
    `(^|[\\s;&|(])git(\\s+(-[Cc]\\s+\\S+|--?[\\w-]+(=\\S+)?))*\\s+(${names})\\b`,
    "u",
  );
}

const DISCARDS = "discards or shelves uncommitted work, including other sessions' changes";

/**
 * Refused to every subagent: these discard or shelve working-tree changes,
 * including the main session's uncommitted harness edits.
 */
const SUBAGENT_REFUSED: readonly (readonly [RegExp, string])[] = [
  [/\bgit\b[^;&|]*\breset\b[^;&|]*--hard\b/u, DISCARDS],
  [gitSubcommand("clean|stash"), DISCARDS],
  [/\bgit\b[^;&|]*\b(checkout|restore)\b[^;&|]*\s(--\s+)?\.(\s|$)/u, DISCARDS],
];

/** Commands that record commits: checked against every changed path for subagents. */
const COMMIT_PRODUCING = gitSubcommand("commit|commit-tree|cherry-pick|merge|revert|rebase|pull|am");

/**
 * Refused only when the command would also mutate: a command merely reading
 * (`cat .cache/stop-gate/judged`, ...) changes nothing and is allowed.
 */
const MUTATION_GATED_REFUSED: readonly (readonly [RegExp, string])[] = [
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

/** A segment that changes directory: `cd <dir>`. */
const CD = /^\s*cd\s+(\S+)\s*$/u;

/** Whether the command writes a file, or runs one, instead of only reading it. */
function mutatesFilesystem(command: string): boolean {
  if (WRITE_VERBS.test(command)) return true;
  if (HAS_REDIRECT.test(command.replaceAll(STREAM_NOISE, ""))) return true;

  return EXEC_VERBS.test(command);
}

/** Strips a token's surrounding quotes. */
function unquote(token: string): string {
  return token.replaceAll(/^['"]|['"]$/gu, "");
}

/** Expands the two directory variables an agent habitually writes paths with. */
function expandDirectoryVariables(command: string, root: string, cwd: string): string {
  return command
    .replaceAll(/\$\{?CLAUDE_PROJECT_DIR\}?/gu, root)
    .replaceAll(/\$\{?PWD\}?/gu, cwd);
}

/** A command token resolved to a repository-relative path, against the segment's directory. */
function resolveToken(token: string, root: string, dir: string): string {
  return path.relative(root, path.resolve(dir, token)).split(path.sep).join("/");
}

/** Whether a repository-relative path lies inside the repository. */
function insideRepository(resolved: string): boolean {
  return resolved !== ".." && !resolved.startsWith("../") && !path.isAbsolute(resolved);
}

/** Whether a repository-relative path is, or is under, a directory. */
function under(resolved: string, dir: string): boolean {
  return resolved === dir || resolved.startsWith(`${dir}/`);
}

/**
 * Whether `role` may not write the repository-relative path `resolved`.
 * - every caller: the always-protected paths
 * - main: nothing else (the human approves its harness changes in conversation)
 * - restricted (implementers, any unnamed subagent): the harness registry
 *   (quality/protected-paths.txt, which lists acceptance/ and PRODUCT.md too)
 * - acceptance-writer: everything inside the repository except acceptance/
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
      return insideRepository(resolved) && !under(resolved, ACCEPTANCE_DIR);
    case "restricted":
      return isProtected(resolved, entries);
  }
}

/** Every path a commit could record, repository-relative. */
export type ChangeLister = (root: string) => string[];

/**
 * Lists every changed path with git: staged, unstaged and untracked (not
 * ignored). All three, because a single command can stage and commit
 * (`git add x && git commit`, `git commit -- x`, `commit -a`), and the hook
 * runs before it. NUL-separated with rename detection off, so a rename lists
 * both sides and a non-ASCII name is not quoted.
 */
export function listChangedPaths(root: string): string[] {
  const run = (args: string[]): string[] =>
    execFileSync("git", ["-c", "core.quotePath=false", ...args], { cwd: root, encoding: "utf8" })
      .split("\0")
      .filter((file) => file !== "");

  return [
    ...run(["diff", "--cached", "--name-only", "--no-renames", "-z"]),
    ...run(["diff", "--name-only", "--no-renames", "-z"]),
    ...run(["ls-files", "--others", "--exclude-standard", "-z"]),
  ];
}

/**
 * The reason a commit-producing command by a subagent is refused, or null.
 * Deliberately conservative: any changed path the role may not write blocks
 * the commit, even one the command would leave out.
 */
function commitViolation(
  command: string,
  entries: readonly string[],
  root: string,
  role: Role,
  listChanged: ChangeLister,
): string | null {
  if (role === "main" || !COMMIT_PRODUCING.test(command)) return null;
  if (role === "reviewer") return "a reviewer reports findings; it does not commit";

  const banned = listChanged(root).find((file) => isBannedTarget(file, entries, role));

  return banned === undefined
    ? null
    : `the working tree has a change to ${banned}, which this role may not commit; leave it to the main session`;
}

/** The first path a segment writes that the role may not write, or undefined. */
function segmentViolation(
  segment: string,
  entries: readonly string[],
  root: string,
  dir: string,
  role: Role,
): string | undefined {
  const withoutNoise = segment.replaceAll(STREAM_NOISE, "");
  const redirected = [...withoutNoise.matchAll(REDIRECT)]
    .map((match) => resolveToken(unquote(match[1] ?? ""), root, dir))
    .find((resolved) => isBannedTarget(resolved, entries, role));

  if (redirected !== undefined) return redirected;
  if (!WRITE_VERBS.test(segment)) return undefined;

  return segment
    .split(/[\s<>()]+/u)
    .filter((token) => token !== "")
    .slice(1)
    .map((token) => unquote(token).replace(/^[a-z]+=/u, ""))
    .filter((token) => token !== "" && !token.startsWith("-"))
    .map((token) => resolveToken(token, root, dir))
    .find((resolved) => isBannedTarget(resolved, entries, role));
}

/** The reason a shell command is refused, or null. */
export function bannedCommand(
  rawCommand: string,
  entries: readonly string[],
  root: string,
  cwd?: string,
  role: Role = "restricted",
  listChanged: ChangeLister = listChangedPaths,
): string | null {
  const startDir = cwd === undefined ? root : path.resolve(root, cwd);
  const command = expandDirectoryVariables(rawCommand, root, startDir);

  for (const [pattern, reason] of ALWAYS_REFUSED) {
    if (pattern.test(command)) return reason;
  }

  if (role !== "main") {
    for (const [pattern, reason] of SUBAGENT_REFUSED) {
      if (pattern.test(command)) return reason;
    }
  }

  for (const [pattern, reason] of MUTATION_GATED_REFUSED) {
    if (pattern.test(command) && mutatesFilesystem(command)) return reason;
  }

  // Segments run left to right; a `cd` moves the directory later segments
  // resolve their paths against.
  let dir = startDir;

  for (const segment of command.split(/&&|\|\||[;|]/u)) {
    const cd = CD.exec(segment);

    if (cd !== null) {
      dir = path.resolve(dir, unquote(cd[1] ?? "."));
      continue;
    }

    const violation = segmentViolation(segment, entries, root, dir, role);

    if (violation !== undefined) return `the command writes near the protected path ${violation}`;
  }

  return commitViolation(command, entries, root, role, listChanged);
}
