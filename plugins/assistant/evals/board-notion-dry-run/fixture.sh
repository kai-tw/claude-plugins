#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
set -euo pipefail
mkdir -p .claude
printf 'vcs: git\nboard: notion\nnotion_root: abcdefabcdefabcdefabcdefabcdefab\ngate: dart test\n' > .claude/assistant.md
