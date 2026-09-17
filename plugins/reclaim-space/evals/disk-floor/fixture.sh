#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
set -euo pipefail
git init -q
printf '%s\n' '{"tool_input":{"command":"git -C repo worktree add ../wt"}}' > add.json
printf '%s\n' '{"tool_input":{"command":"git worktree list"}}' > list.json
