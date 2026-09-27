#!/bin/sh
# quiet.sh — run a command and print one line on success, only the failure on failure.
#
# Usage: scripts/quiet.sh <label> <command> [args...]
#
# Every make target and hook step goes through this wrapper so that an agent
# reading the output sees "ok: <label>" or "FAIL: <label>" followed by the
# diagnostics, and nothing else. Set MONEGING_VERBOSE=1 to see everything.
set -u

label=$1
shift

if [ "${MONEGING_VERBOSE:-0}" = "1" ]; then
  echo "run: $label"
  exec "$@"
fi

out=$(mktemp "${TMPDIR:-/tmp}/moneging-quiet.XXXXXX")

"$@" >"$out" 2>&1
status=$?

if [ "$status" -eq 0 ]; then
  echo "ok: $label"
  rm -f "$out"
  exit 0
fi

echo "FAIL: $label (exit $status)"

# Strip the progress noise of the tools so only diagnostics remain.
sed -e 's/\x1b\[[0-9;]*m//g' "$out" \
  | grep -vE '^(BUILD (SUCCESSFUL|FAILED)( in .*)?|> Task :[A-Za-z0-9:._-]+( [A-Z-]+)?)$' \
  | grep -vE '^(cd |make(\[[0-9]+\])?: (Entering|Leaving) directory)' \
  | grep -vE '^[[:space:]]*$'

rm -f "$out"
exit "$status"
