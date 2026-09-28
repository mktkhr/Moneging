#!/bin/sh
# Harness protection guard.
#
# The Repository Harness (quality policies, guards, hooks, CI, Makefile, the
# acceptance criteria and their tests) must not change as a side effect of
# product work. This script fails when a protected path differs from the base.
# It fails closed: when no base can be found, that is an error, not a pass.
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
cd "$(dirname "$0")/../.."

if [ "${MONEGING_ALLOW_HARNESS_CHANGE:-0}" = "1" ]; then
  echo "protected-paths: harness change acknowledged"
  exit 0
fi

paths=$(grep -vE '^[[:space:]]*(#|$)' quality/protected-paths.txt)

if [ "${1:-}" = "--staged" ]; then
  if ! git rev-parse --verify -q HEAD >/dev/null; then
    echo "protected-paths: first commit, nothing to protect yet"
    exit 0
  fi
  changed=$(git diff --cached --name-only -- $paths)
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
fi

if [ -z "$changed" ]; then
  echo "protected-paths: harness untouched"
  exit 0
fi

echo "protected-paths: these Repository Harness files changed:"
printf '%s\n' "$changed" | sed 's/^/  /'
echo
echo "The harness is not part of product work. Fix the code, not the check."
echo "If the harness itself is wrong, stop and tell the human what and why;"
echo "only the human changes it, by running a script outside the repository."
exit 1
