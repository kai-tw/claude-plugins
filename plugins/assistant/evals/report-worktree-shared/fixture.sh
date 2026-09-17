#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
set -euo pipefail
git init -q
git -c user.name=e -c user.email=e@e commit -q --allow-empty -m init
git worktree add -q wt
