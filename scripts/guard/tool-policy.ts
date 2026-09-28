/**
 * Claude Code PreToolUse hook: the harness enforced at the tool, before a
 * change reaches git. Exit code 2 blocks the call and shows stderr to Claude.
 *
 * Governs Edit, MultiEdit, Write and NotebookEdit (by path) and Bash (by
 * command, in scripts/guard/bash-policy.ts). What a caller may write depends
 * on its role (scripts/guard/roles.ts): subagents doing product work cannot
 * touch the harness (quality/protected-paths.txt) or the acceptance tests;
 * the acceptance writer cannot touch the harness or product code; a reviewer
 * writes nothing; the main session, which changes the harness only after the
 * human approves it in conversation, is bound only by the always-protected
 * paths.
 */
import { existsSync, readFileSync, realpathSync } from "node:fs";
import path from "node:path";

import { bannedCommand, isBannedTarget } from "./bash-policy.ts";
import { isProtected, protectedEntries } from "./protected-entries.ts";
import { type Role, roleOf } from "./roles.ts";

export interface HookInput {
  readonly tool_name: string;
  readonly tool_input: Readonly<Record<string, unknown>>;
  readonly cwd?: string;
  readonly agent_id?: string;
  readonly agent_type?: string;
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

/** null to allow the call, or the reason to refuse it. The role defaults to the most restricted subagent. */
export function decide(
  input: HookInput,
  root: string,
  entries: readonly string[],
  role: Role = "restricted",
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

    const banned = candidates.find((candidate) => isBannedTarget(candidate, entries, role));

    if (banned !== undefined) return `${relative} is not writable by this role (${role})`;

    return null;
  }

  if (input.tool_name === "Bash" && typeof input.tool_input["command"] === "string") {
    return bannedCommand(input.tool_input["command"], entries, root, input.cwd, role);
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

    const reason = decide(parsed, root, entries, roleOf(parsed));

    if (reason === null) return 0;

    process.stderr.write(
      `Refused by the Repository Harness: ${reason}.\n` +
        "Fix the product code instead. A refusal is information about the plan, not an obstacle\n" +
        "to route around. If the harness or the acceptance tests must change, stop and report what\n" +
        "and why; the main session makes that change after the human approves it.\n",
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
