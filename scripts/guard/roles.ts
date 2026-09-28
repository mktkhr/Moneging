/**
 * Who is calling a tool, as far as the harness is concerned.
 *
 * Claude Code adds `agent_id` and `agent_type` to a hook's input only when
 * the tool call comes from inside a subagent. The harness guards against the
 * agents that do the product work weakening what checks that work: an
 * implementer that edits the lint policy, the acceptance tests or the spec
 * until they pass. The main session is the one the human talks to; it
 * changes the harness only after the human approves the change in the
 * conversation, so it is not restricted here.
 *
 * Deny by default: any subagent that is not one of the named roles below is
 * treated as an implementer, so a new or misnamed agent type never gains
 * write access to the harness. The mere presence of either key marks a
 * subagent, whatever its value, so a malformed id never reads as the main
 * session.
 */

export type Role = "main" | "acceptance-writer" | "reviewer" | "restricted";

/** The directory of the executable acceptance criteria (PRODUCT.md §7): the acceptance writer's only writable area. */
export const ACCEPTANCE_DIR = "acceptance";

/** The role of the caller described by a hook input. */
export function roleOf(input: Readonly<Record<string, unknown>>): Role {
  if (!("agent_id" in input) && !("agent_type" in input)) return "main";

  const agentType = input["agent_type"];

  if (agentType === "acceptance-writer") return "acceptance-writer";
  if (agentType === "reviewer") return "reviewer";

  return "restricted";
}
