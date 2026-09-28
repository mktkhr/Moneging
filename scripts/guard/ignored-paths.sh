#!/bin/sh
# Ignore guard.
#
# A protected path that git ignores is a protected path that never reaches the
# repository, so a quality gate can be removed without editing a protected file
# at all. Moneging's .gitignore is deny-by-default (`*`, then `!` allows), so
# this failure mode is one line away: dropping a single `!path/**` allow line
# re-ignores everything under that path while leaving the bare directory
# itself unignored (its own `!path/` entry still applies) - `git check-ignore`
# on the directory name alone would miss exactly that. It would also miss any
# already-tracked file under it by default: "tracked files are not shown at
# all since they are not subject to exclude rules" (git-check-ignore(1)). So
# every tracked file under a protected directory is checked explicitly, with
# --no-index, rather than the directory name or only its untracked contents.
#
# quality/protected-paths.txt lists what must never be ignored.
set -eu
cd "$(git rev-parse --show-toplevel)"

registry="quality/protected-paths.txt"
ignored=""

# Appends each line of $1, if any, to $ignored as real newline-separated
# entries (never as a printf format string - a matched path could itself
# contain a literal '%').
add() {
  [ -n "$1" ] || return 0
  if [ -z "$ignored" ]; then
    ignored=$1
  else
    ignored="$ignored
$1"
  fi
}

# Runs `git check-ignore --no-index` (over stdin's paths, or a single
# argument) without letting `set -e` abort on its ordinary "not ignored" exit
# status. Sets $ci_out and $ci_status; git-check-ignore(1): 0 = one or more
# paths ignored, 1 = none ignored, 128 = a fatal error (not a verdict at all -
# stop instead of silently treating it as "clean").
check_ignore() {
  if ci_out=$(git check-ignore --no-index "$@" 2>/dev/null); then
    ci_status=0
  else
    ci_status=$?
  fi
}

while IFS= read -r entry; do
  case $entry in ''|\#*) continue ;; esac
  [ -e "$entry" ] || continue

  if [ -d "$entry" ]; then
    # Every tracked source already in the repository under this directory:
    # evaluated against the patterns themselves (--no-index), not skipped for
    # being tracked.
    tracked=$(git ls-files -- "$entry")
    if [ -n "$tracked" ]; then
      check_ignore --stdin <<EOF
$tracked
EOF
      if [ "$ci_status" -gt 1 ]; then
        echo "ignored-paths: git check-ignore failed (exit $ci_status) checking tracked files under $entry" >&2
        exit 1
      fi
      add "$ci_out"
    fi

    # New, not-yet-tracked sources anywhere under this directory that a fresh
    # ignore rule would silently swallow before they are ever committed.
    # Scanned recursively (bare pathspec), then narrowed to source-like
    # extensions, plus hooks/ files by name (they are conventionally
    # extensionless: commit-msg, pre-commit, pre-push) - so a directory's own
    # build/cache output, at any depth, is not flagged: a gate that forbids
    # ignoring its own artifacts leaves no way out for an agent that cannot
    # write to quality/ either. .claude/settings.local.json and
    # .claude/worktrees/ are exempt outright: written by Claude Code itself
    # (local settings, worktree checkouts) and never committed, not a gate
    # going dark.
    inner=$(git ls-files --others --ignored --exclude-standard -- "$entry" 2>/dev/null \
      | grep -vFx ".claude/settings.local.json" \
      | grep -v '^\.claude/worktrees/' \
      | grep -E '\.(sh|ts|js|mjs|json|ya?ml|txt|md)$|^hooks/[^/]+$' \
      || true)
    add "$inner"
  else
    check_ignore "$entry"
    if [ "$ci_status" -gt 1 ]; then
      echo "ignored-paths: git check-ignore failed (exit $ci_status) checking $entry" >&2
      exit 1
    fi
    add "$ci_out"
  fi
done < "$registry"

if [ -n "$ignored" ]; then
  echo "protected paths are git-ignored:"
  sorted=$(printf '%s\n' "$ignored" | sort -u)
  total=$(printf '%s\n' "$sorted" | grep -c .)
  printf '%s\n' "$sorted" | head -50 | sed 's/^/  /'
  if [ "$total" -gt 50 ]; then
    echo "  ... and $((total - 50)) more"
  fi
  echo "The quality baseline must be in the repository. Restore those .gitignore allow lines."
  exit 1
fi

echo "ignored-paths: no protected path is ignored"
