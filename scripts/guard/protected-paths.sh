#!/bin/sh
# Harness protection guard.
#
# The Repository Harness (quality policies, guards, hooks and the Makefile)
# must not change as a side effect of product work while LOCKED. This script
# fails when a protected path differs from the base while LOCKED. It fails
# closed: when no base can be found, that is an error, not a pass.
#
# The always-protected set (the harness lock file and its parser - see
# scripts/guard/harness-lock.ts) is checked separately below and always
# requires MONEGING_ALLOW_HARNESS_CHANGE=1, locked or unlocked. It is
# hardcoded here, independently of the TypeScript registry
# (scripts/guard/protected-entries.ts), so a bug or an oversight in that
# registry - it is only locked-gated, not always-protected, so it can be
# edited during an unlocked window - does not silently also disable this
# git-level check. It is not a defence against a deliberate edit made here or
# in that registry during an unlocked window: only the human's review before
# committing (and before running `make harness-approve`) is that defence.
#
# Usage:
#   protected-paths.sh --staged      the index against HEAD (pre-commit)
#   protected-paths.sh [<base-ref>]  commits since the base, uncommitted and
#                                    untracked files (make check, CI). The base
#                                    is <base-ref>, else $MONEGING_BASE_REF,
#                                    else refs/harness/approved (the last
#                                    harness state the human approved), else
#                                    origin/main, else main.
set -eu
cd "$(git rev-parse --show-toplevel)"

always_paths="quality/harness-lock.txt scripts/guard/harness-lock.ts"

paths=$(grep -vE '^[[:space:]]*(#|$)' quality/protected-paths.txt)

# The lock is read from refs/harness/approved (scripts/guard/harness-lock.ts),
# not the working tree, so this passes the toplevel it just resolved above as
# the root explicitly - the CLI must not fall back to $CLAUDE_PROJECT_DIR
# here, which may be stale, unset, or unrelated when this runs from a git
# hook, `make`, or a human's own shell rather than a live Claude Code session.
lock_line=$(node scripts/guard/harness-lock.ts "$PWD" 2>/dev/null || true)
case $lock_line in
  unlocked\ *) locked=0; lock_date=${lock_line#unlocked } ;;
  *) locked=1; lock_date="" ;;
esac

if [ "${1:-}" = "--staged" ]; then
  if ! git rev-parse --verify -q HEAD >/dev/null; then
    echo "protected-paths: first commit, nothing to protect yet"
    exit 0
  fi
  changed=$(git diff --cached --name-only -- $paths)
  always_changed=$(git diff --cached --name-only -- $always_paths)
else
  base=""
  for candidate in "${1:-}" "${MONEGING_BASE_REF:-}" refs/harness/approved origin/main main; do
    [ -n "$candidate" ] || continue
    if git rev-parse --verify -q "$candidate^{commit}" >/dev/null; then
      base=$candidate
      break
    fi
  done

  if [ -z "$base" ]; then
    echo "protected-paths: no base revision found (tried ${1:-} ${MONEGING_BASE_REF:-} refs/harness/approved origin/main main)"
    echo "Set MONEGING_BASE_REF to the branch this work started from."
    exit 1
  fi

  # refs/harness/approved is compared two-dot: it is the anchor itself, not a
  # branch point, so a revert, reset or cherry-pick of harness files after it
  # must still be seen, even on main with no remote.
  if [ "$base" = refs/harness/approved ]; then
    range="$base HEAD"
  else
    range="$base...HEAD"
  fi

  changed=$( {
    git diff --name-only $range -- $paths
    git diff --name-only HEAD -- $paths
    git ls-files --others --exclude-standard -- $paths
  } | sort -u)
  always_changed=$( {
    git diff --name-only $range -- $always_paths
    git diff --name-only HEAD -- $always_paths
    git ls-files --others --exclude-standard -- $always_paths
  } | sort -u)
fi

if [ -n "$always_changed" ] && [ "${MONEGING_ALLOW_HARNESS_CHANGE:-0}" != "1" ]; then
  echo "protected-paths: these always-protected files changed:"
  printf '%s\n' "$always_changed" | sed 's/^/  /'
  echo
  echo "The harness lock and its parser stay protected even while unlocked. Only the"
  echo "human, having reviewed the change, sets MONEGING_ALLOW_HARNESS_CHANGE=1 and"
  echo "runs make harness-approve."
  exit 1
fi

if [ "$locked" = 0 ]; then
  echo "protected-paths: harness UNLOCKED until $lock_date; protected paths may change without acknowledgement until then"
  exit 0
fi

if [ "${MONEGING_ALLOW_HARNESS_CHANGE:-0}" = "1" ]; then
  echo "protected-paths: harness change acknowledged"
  exit 0
fi

if [ -z "$changed" ]; then
  echo "protected-paths: harness untouched"
  exit 0
fi

echo "protected-paths: the harness is LOCKED and these files changed:"
printf '%s\n' "$changed" | sed 's/^/  /'
echo
echo "The harness is not part of product work while locked. Fix the code, not the"
echo "check. The lock is read from refs/harness/approved, not the working tree: to"
echo "open a window, the human edits quality/harness-lock.txt, commits it (and any"
echo "other harness change) with MONEGING_ALLOW_HARNESS_CHANGE=1 set, then runs"
echo "make harness-approve to record that commit as the approved state."
exit 1
