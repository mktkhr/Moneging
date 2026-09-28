/**
 * The one role the tool policy distinguishes: a reviewer subagent, which
 * reports and writes nothing inside the repository. Every other caller,
 * the main session included, is bound by the same rules (the harness is
 * changed only through an apply script the human approves).
 *
 * Claude Code adds `agent_id` and `agent_type` to a hook's input only when
 * the call comes from inside a subagent; `agent_type` names the subagent.
 */

/** Whether the hook input comes from the reviewer subagent. */
export function isReviewer(input: Readonly<Record<string, unknown>>): boolean {
  return input["agent_type"] === "reviewer";
}
