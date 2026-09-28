#!/bin/sh
# Suppression guard.
#
# Static checks are only worth something when they cannot be silenced ad hoc.
# This script fails when a suppression directive exists in the source tree
# without being registered in quality/suppressions.allow. Registering one is a
# reviewed change to the Repository Harness, not something done in passing.
#
# Covered directives:
#   Kotlin  @Suppress(...), @file:Suppress(...), @SuppressWarnings(...),
#           ktlint-disable / ktlint:disable comments, @Ignore on tests
#   Swift   swiftlint:disable (incl. :next / :this), swift-format-ignore,
#           XCTSkip (incl. XCTSkipIf / XCTSkipUnless), .disabled( on
#           Swift Testing tests
#   Gradle  ignoreFailures / isIgnoreFailures set to true (false is the
#           strict, wanted value and is not flagged), disabled tasks
#           (enabled = false / enabled.set(false)), detekt/Android Lint
#           baseline files
#
# Registry line format (one per line, '#' starts a comment). The source line is
# part of the key so that unrelated edits shifting line numbers do not matter,
# while any change to the suppressed line itself must be re-registered:
#   <path relative to repository root> :: <directive> :: <trimmed source line>
set -eu

cd "$(dirname "$0")/../.."

registry="quality/suppressions.allow"
pattern='@Suppress\(|@file:Suppress\(|@SuppressWarnings\(|ktlint-disable|ktlint:disable|@Ignore\b|swiftlint:disable|swift-format-ignore|XCTSkip|\.disabled\(|(ignoreFailures|isIgnoreFailures)[[:space:]]*(\.set\([[:space:]]*|=[[:space:]]*)true|baseline\.set\(|baselineFile|enabled[[:space:]]*=[[:space:]]*false|enabled\.set\(false\)'

# Paths that are product or tooling source. Build output, caches and IDE state
# are never scanned.
scan_paths="clients/kmp"

found=$(grep -rnE --include='*.kt' --include='*.kts' --include='*.swift' \
  --exclude-dir=build --exclude-dir=.gradle --exclude-dir=.kotlin --exclude-dir=.idea \
  --exclude-dir=DerivedData --exclude-dir=xcuserdata \
  "$pattern" $scan_paths 2>/dev/null \
  | grep -vE '^(quality/suppressions\.allow|scripts/guard/suppressions\.sh):' \
  || true)

status=0
count=0

# Each hit must appear in the registry with the same file, line and directive.
printf '%s\n' "$found" | while IFS= read -r hit; do
  [ -z "$hit" ] && continue
  file=${hit%%:*}
  rest=${hit#*:}
  line=${rest%%:*}
  code=${rest#*:}
  code=$(printf '%s' "$code" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  directive=$(printf '%s' "$rest" | grep -oE "$pattern" | head -n 1)
  key="$file :: $directive :: $code"
  if ! grep -qxF "$key" "$registry" 2>/dev/null; then
    echo "unregistered suppression: $hit"
    echo "  register it as '$key' in $registry (with a reason) or, better, fix the finding"
    echo "$key" >> "${TMPDIR:-/tmp}/moneging-suppressions.$$"
  fi
done

if [ -s "${TMPDIR:-/tmp}/moneging-suppressions.$$" ]; then
  count=$(wc -l < "${TMPDIR:-/tmp}/moneging-suppressions.$$")
  rm -f "${TMPDIR:-/tmp}/moneging-suppressions.$$"
  echo "suppressions: $count unregistered directive(s)"
  exit 1
fi
rm -f "${TMPDIR:-/tmp}/moneging-suppressions.$$"

# Registered entries must still exist, otherwise the registry rots.
grep -vE '^[[:space:]]*(#|$)' "$registry" | while IFS= read -r key; do
  file=${key%% :: *}
  code=${key##* :: }
  if ! grep -qF -- "$code" "$file" 2>/dev/null; then
    echo "stale registry entry: $key (no such line in $file)"
    echo "stale" >> "${TMPDIR:-/tmp}/moneging-suppressions-stale.$$"
  fi
done

if [ -s "${TMPDIR:-/tmp}/moneging-suppressions-stale.$$" ]; then
  rm -f "${TMPDIR:-/tmp}/moneging-suppressions-stale.$$"
  exit 1
fi
rm -f "${TMPDIR:-/tmp}/moneging-suppressions-stale.$$"

total=$(printf '%s\n' "$found" | grep -c . || true)
echo "suppressions: $total directive(s), all registered"
exit $status
