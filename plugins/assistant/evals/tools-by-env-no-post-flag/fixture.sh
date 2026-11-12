#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
set -euo pipefail
git init -q wt
cd wt
git config user.email e@e; git config user.name e
mkdir -p .claude
printf 'vcs: git\n' > .claude/assistant.md
printf '.claude/.assistant/\n' > .gitignore
git add -A; git commit -qm base
git switch -qc task/r
