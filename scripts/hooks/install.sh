#!/bin/sh
# Points git at the repository owned hooks directory.
# Runs from `make hooks`; harmless outside a git checkout.
set -eu
cd "$(dirname "$0")/../.."
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  git config core.hooksPath hooks
  echo "git hooks: core.hooksPath=hooks"
fi
