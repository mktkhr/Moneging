/**
 * Who is calling a tool, as far as the harness is concerned.
 *
 * Claude Code adds `agent_id` and `agent_type` to a hook's input only when
 * the tool call comes from inside a subagent. The harness guards against the
 * agents that do the product work weakening what checks that work: an
 * implementer that edits the lint policy or the acceptance tests until they
 * pass. The main session is the one the human talks to; it changes the
 * harness only after the human approves the change in the conversation, so
 * it is not restricted here.
 *
 * Deny by default: any subagent that is not one of the named roles below is
 * treated as an implementer, so a new or misnamed agent type never gains
 * write access to the harness.
 */

export type Role = "main" | "acceptance-writer" | "reviewer" | "restricted";

/** The directory of the executable acceptance criteria (PRODUCT.md §7). */
export const ACCEPTANCE_DIR = "acceptance";

/** Product source trees: the acceptance writer reads them but never writes them. */
export const PRODUCT_DIRS: readonly string[] = ["clients", "services", "contracts", "infra"];

/** The role of the caller described by a hook input. */
export function roleOf(input: Readonly<Record<string, unknown>>): Role {
  const agentId = input["agent_id"];

  if (typeof agentId !== "string" || agentId === "") return "main";

  const agentType = input["agent_type"];

  if (agentType === "acceptance-writer") return "acceptance-writer";
  if (agentType === "reviewer") return "reviewer";

  return "restricted";
}
