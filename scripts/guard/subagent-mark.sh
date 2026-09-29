#!/bin/sh
# Claude Code SubagentStart / SubagentStop hook: keeps a mark per running
# subagent, so that stop-gate.sh does not judge the main session's stop while a
# subagent is still writing to the tree.
#
# Usage: sh subagent-mark.sh start|stop   (the hook input JSON on stdin)
# A mark older than stop-gate.sh's limit is ignored there, so a subagent whose
# SubagentStop never fired cannot switch the gate off for good.
set -u
cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"

running=.cache/stop-gate/running
mkdir -p "$running"

# The agent's id, reduced to a safe file name; nothing to mark without one.
id=$(sed -n 's/.*"agent_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1 | tr -cd 'A-Za-z0-9_-')
if [ -z "$id" ]; then
  exit 0
fi

case ${1:-} in
  start) : >"$running/$id" ;;
  stop) rm -f "$running/$id" ;;
esac

exit 0
