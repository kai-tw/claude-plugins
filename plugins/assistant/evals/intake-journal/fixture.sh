#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
set -euo pipefail
git init -q
mkdir -p docs/session-journal
cat > docs/session-journal/_active.md <<'MD'
# In-flight threads — cross-session index

<!-- ## <thread title> · <status>
- **Next:** <one concrete line> -->

## Export dialog · in progress
- **Lives:** worktree .claude/worktrees/export
- **Next:** wire the share sheet
- **Detail:** docs/session-journal/abc/

## Font cache · blocked
- **Lives:** main tree
MD
