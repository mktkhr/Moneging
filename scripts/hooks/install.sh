#!/bin/sh
# Points git at the repository owned hooks directory.
# Runs from `make hooks`; harmless outside a git checkout.
set -eu
cd "$(dirname "$0")/../.."
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  git config core.hooksPath hooks
  echo "git hooks: core.hooksPath=hooks"

  # refs/harness/approved is the last harness state the human approved
  # (an approved apply script moves it). A fresh clone has none yet: anchor it
  # at HEAD so guard-protected has a base from the first commit on.
  if ! git rev-parse --verify -q refs/harness/approved >/dev/null; then
    if git rev-parse --verify -q HEAD >/dev/null 2>&1; then
      git update-ref refs/harness/approved HEAD
      echo "harness: approved state initialised at $(git rev-parse --short HEAD)"
    fi
  fi
fi
