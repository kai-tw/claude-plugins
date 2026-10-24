#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
set -euo pipefail
git init -q wt
mkdir -p wt/.claude
printf 'vcs: git\n' > wt/.claude/assistant.md
