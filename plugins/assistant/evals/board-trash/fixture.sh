#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
set -euo pipefail
mkdir -p .claude
printf 'vcs: svn\nboard: file\nkb: docs/decisions\ngate: npm test\n' > .claude/assistant.md
