#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
set -euo pipefail
mkdir -p .claude
printf 'vcs: git\nboard: file\nkb: docs/kb\ngate: npm test\n' > .claude/assistant.md
