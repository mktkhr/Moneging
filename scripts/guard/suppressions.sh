#!/bin/sh
# Suppression guard: see scripts/guard/suppressions.ts for what is covered and
# the quality/suppressions.allow registry format. Runs against the git
# repository containing the current directory.
set -eu
exec node "$(dirname "$0")/suppressions.ts" "$@"
