/**
 * Claude Code PreToolUse hook: the harness enforced at the tool, before a
 * change reaches git. Exit code 2 blocks the call and shows stderr to Claude.
 *
 * Governs Edit, MultiEdit, Write and NotebookEdit (by path) and Bash (by
 * command, in scripts/guard/bash-policy.ts). The protected list is
 * quality/protected-paths.txt, the same list the pre-commit hook and
 * `make guard-protected` read. A protected path is refused unconditionally,
 * the main session included: a harness change is an apply script the human
 * approves, never something a session writes in place. A reviewer subagent
 * (scripts/guard/roles.ts) writes nothing inside the repository at all.
 */
import { existsSync, readFileSync, realpathSync } from "node:fs";
import path from "node:path";

import { bannedCommand } from "./bash-policy.ts";
import { ALWAYS_PROTECTED, isProtected, protectedEntries } from "./protected-entries.ts";
import { isReviewer } from "./roles.ts";

export interface HookInput {
  readonly tool_name: string;
  readonly tool_input: Readonly<Record<string, unknown>>;
  readonly cwd?: string;
  readonly agent_id?: unknown;
  readonly agent_type?: unknown;
}

export { bannedCommand, isProtected, protectedEntries };

const PATH_TOOLS = new Set(["Edit", "MultiEdit", "Write", "NotebookEdit"]);

const STOP_GATE_DIR = ".cache/stop-gate";

/** Narrows an unknown value from JSON.parse into HookInput without a cast. */
function isHookInput(value: unknown): value is HookInput {
  if (typeof value !== "object" || value === null) return false;
  if (!("tool_name" in value) || typeof value.tool_name !== "string") return false;
  if (!("tool_input" in value) || typeof value.tool_input !== "object" || value.tool_input === null)
    return false;

  return true;
}

/**
 * Resolves a target through the filesystem so a protected path cannot be
 * reached through a symlink elsewhere: walks up from the target to the
 * nearest existing ancestor, resolves that ancestor's real path, re-appends
 * the missing tail, and makes the result relative to the root's real path.
 * Returns null when `root` itself does not exist (as in the unit tests,
 * which use a synthetic root): only the lexical path is checked then.
 */
function resolveRelative(root: string, target: string): string | null {
  if (!existsSync(root)) return null;

  let ancestor = path.resolve(root, target);
  let tail = "";

  while (!existsSync(ancestor)) {
    tail = tail === "" ? path.basename(ancestor) : path.join(path.basename(ancestor), tail);
    const parent = path.dirname(ancestor);

    if (parent === ancestor) return null;
    ancestor = parent;
  }

  const resolvedAncestor = realpathSync(ancestor);
  const resolved = tail === "" ? resolvedAncestor : path.join(resolvedAncestor, tail);

  return path.relative(realpathSync(root), resolved).split(path.sep).join("/");
}

/** null to allow the call, or the reason to refuse it. */
export function decide(
  input: HookInput,
  root: string,
  entries: readonly string[],
  reviewer = false,
): string | null {
  if (PATH_TOOLS.has(input.tool_name)) {
    const target = input.tool_input["file_path"] ?? input.tool_input["notebook_path"];

    if (typeof target !== "string") return "the tool call names no file path the harness can check";

    const relative = path.relative(root, path.resolve(root, target)).split(path.sep).join("/");
    const resolved = resolveRelative(root, target);
    const candidates = resolved === null ? [relative] : [relative, resolved];

    if (
      candidates.some(
        (candidate) => candidate === STOP_GATE_DIR || candidate.startsWith(`${STOP_GATE_DIR}/`),
      )
    )
      return "only the Stop hook records a verified tree";
    if (candidates.some((candidate) => isProtected(candidate, ALWAYS_PROTECTED)))
      return "git internals and the local Claude settings are never a session's to edit";
    if (candidates.some((candidate) => isProtected(candidate, entries)))
      return `${relative} is part of the harness (quality/protected-paths.txt)`;
    if (reviewer) return "a reviewer writes nothing inside the repository";

    return null;
  }

  if (input.tool_name === "Bash" && typeof input.tool_input["command"] === "string") {
    return bannedCommand(input.tool_input["command"], entries, root, input.cwd, reviewer);
  }

  return null;
}

/** Runs the hook; never throws, so a crash refuses instead of allowing. */
function main(): number {
  try {
    const root = process.env["CLAUDE_PROJECT_DIR"] ?? process.cwd();
    const entries = protectedEntries(
      readFileSync(path.join(root, "quality/protected-paths.txt"), "utf8"),
    );
    const parsed: unknown = JSON.parse(readFileSync(0, "utf8"));

    if (!isHookInput(parsed)) {
      process.stderr.write("tool-policy: malformed hook input on stdin\n");
      return 2;
    }

    const reason = decide(parsed, root, entries, isReviewer(parsed));

    if (reason === null) return 0;

    process.stderr.write(
      `Refused by the Repository Harness: ${reason}.\n` +
        "Fix the product code instead. A refusal is information about the plan, not an obstacle\n" +
        "to route around. If the harness itself must change, write the change as a bundle outside\n" +
        "the repository (full replacement files plus an apply.sh that copies them in, runs\n" +
        "make harness-check, commits and moves refs/harness/approved), explain it, and stop:\n" +
        "running it is the human's approval (docs/handbook/harness.md).\n",
    );

    return 2;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);

    process.stderr.write(`tool-policy: ${message}; refusing\n`);

    return 2;
  }
}

if (process.argv[1] !== undefined && path.resolve(process.argv[1]) === import.meta.filename) {
  process.exitCode = main();
}
