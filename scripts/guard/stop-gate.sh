#!/bin/sh
# Claude Code Stop hook: a turn does not end on a tree that got worse.
#
# Exit code 2 keeps Claude working and shows it stderr; exit 0 with a JSON
# systemMessage ends the turn and tells the user the tree is still red.
#   1. Untracked sources are refused: a next session cannot recover them.
#   2. `make harness-check` must be green: the harness itself is always fixable.
#      (Run once, as part of `make -k verify` below - not a second time - so
#      its failure is read from that one run's output.)
#   3. `make -k verify` may be red, but no gate other than harness-check may
#      fail that did not fail at the last stop. The first stop records the
#      failing gates as the baseline.
# A tree already judged is not judged again. After three refusals in a row the
# turn ends anyway and the user is told, and that verdict is cached by tree
# key (like a pass is): an unchanged tree is not re-attempted turn after turn,
# so a condition Claude cannot fix (see below) does not cycle "refuse x3, give
# up, refuse x3, give up, ..." forever. It resumes judging once the tree
# actually changes.
set -u
cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"

state=.cache/stop-gate
mkdir -p "$state"

# key: the tree of the whole working tree including staged, unstaged and
# untracked-but-not-ignored files, computed against a scratch index so the
# real index is never touched.
tmpdir=$(mktemp -d)
key=$(GIT_INDEX_FILE="$tmpdir/index" git add -A -- . >/dev/null 2>&1 \
  && GIT_INDEX_FILE="$tmpdir/index" git write-tree)
rm -rf "$tmpdir"

key_valid=0
case $key in
  ????????????????????????????????????????) key_valid=1 ;;
esac
case $key in
  *[!0-9a-f]*) key_valid=0 ;;
esac

if [ "$key_valid" = 1 ] && [ -f "$state/judged" ] && [ "$(cat "$state/judged")" = "$key" ]; then
  exit 0
fi

if [ "$key_valid" = 1 ] && [ -f "$state/gaveup" ] && [ "$(cat "$state/gaveup")" = "$key" ]; then
  exit 0
fi

# refuse <message>: block the stop (called in this shell, never in a
# pipeline, so that its exit ends the script).
refuse() {
  attempts=$(( $(cat "$state/attempts" 2>/dev/null || echo 0) + 1 ))
  echo "$attempts" >"$state/attempts"

  if [ "$attempts" -gt 3 ]; then
    rm -f "$state/attempts"
    if [ "$key_valid" = 1 ]; then
      printf '%s\n' "$key" >"$state/gaveup"
    fi
    printf '{"systemMessage":"stop-gate: gave up after three refusals; the tree is still red (run make -k verify). This exact tree will not be re-judged until it changes."}\n'
    exit 0
  fi

  printf '%s\n' "$1" >&2
  exit 2
}

untracked=$(git ls-files --others --exclude-standard -- \
  '*.kt' '*.kts' '*.swift' '*.ts' '*.tsx' '*.sh' '*.yaml' '*.yml' '*.toml' '*.json' '*.md' '*.gradle' '*.pbxproj')
if [ -n "$untracked" ]; then
  refuse "$(echo "stop-gate: untracked files; commit them with the work they belong to, or delete them:"; printf '%s\n' "$untracked" | head -20 | sed 's/^/  /')"
fi

out=$(make -k verify 2>&1)
code=$?
# Only lines quiet.sh itself produces, not a line a guarded tool's own output
# happens to print (a test asserting on "FAIL: kmp-test" text must not
# pre-authorise that gate to fail).
failing=$(printf '%s\n' "$out" \
  | grep -E '^FAIL: [A-Za-z0-9:._/-]+ \(exit [0-9]+\)$' \
  | sed -E 's/^FAIL: ([A-Za-z0-9:._/-]+) \(exit [0-9]+\)$/\1/' \
  | sort -u)

# An uncommitted edit to an always-protected path (quality/harness-lock.txt,
# scripts/guard/harness-lock.ts) can only be the human's: tool-policy refuses
# it to every session, locked or not. guard-protected fails first and only on
# that check when one is dirty (scripts/guard/protected-paths.sh), so its
# failure is not Claude's to fix; drop it from the failing set so it neither
# blocks this stop nor gets "fixed" by waiting it out.
if [ -n "$(git status --porcelain -- quality/harness-lock.txt scripts/guard/harness-lock.ts 2>/dev/null)" ]; then
  failing=$(printf '%s\n' "$failing" | grep -v '^guard-protected$' || true)
fi

tmpstate=$(mktemp -d)
printf '%s\n' "$failing" | awk 'NF' >"$tmpstate/failing"

new=""
if [ -f "$state/failing" ]; then
  sort -u "$state/failing" >"$tmpstate/baseline"
  new=$(comm -23 "$tmpstate/failing" "$tmpstate/baseline")
fi
rm -rf "$tmpstate"

# harness-check is always fixable, so unlike the other gates its failure
# refuses even when it also failed at the last stop, not only when new.
harness_check_failing=$(printf '%s\n' "$failing" | grep '^harness-check' || true)
if [ -n "$harness_check_failing" ]; then
  refuse "$(echo "stop-gate: make harness-check is red; the harness must stay green. Fix what it prints."; printf '%s\n' "$out" | grep -v '^ok: ' | head -80)"
fi

if [ -n "$new" ]; then
  refuse "$(echo "stop-gate: these gates passed at the last stop and fail now:"; printf '%s\n' "$new"; printf '%s\n' "$out" | grep -v '^ok: ' | head -80)"
fi

printf '%s\n' "$failing" | awk 'NF' >"$state/failing"
rm -f "$state/attempts" "$state/gaveup"
if [ "$key_valid" = 1 ]; then
  printf '%s\n' "$key" >"$state/judged"
fi

if [ "$code" -ne 0 ]; then
  # Gate names reach the systemMessage's JSON string, so any name that does
  # not match the plain [A-Za-z0-9:._/-]+ shape (e.g. one holding a quote) is
  # dropped rather than trusted to keep the message valid JSON.
  gates=$(printf '%s\n' "$failing" | grep -E '^[A-Za-z0-9:._/-]+$' | tr '\n' ' ' | sed 's/ $//')
  printf '{"systemMessage":"stop-gate: make verify is still red (%s); no gate got worse"}\n' "$gates"
fi

exit 0
