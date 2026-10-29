#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# ./ is a file board; legacy/ holds a board.md written with a Trigger column.
set -euo pipefail
mkdir -p .claude legacy/.claude/.assistant
printf 'vcs: svn\nboard: file\nkb: docs/decisions\ngate: npm test\n' > .claude/assistant.md
printf 'vcs: svn\nboard: file\nkb: docs/decisions\ngate: npm test\n' > legacy/.claude/assistant.md
cat > legacy/.claude/.assistant/board.md <<'MD'
| Slug | Name | Status | Stage | Trigger |
|---|---|---|---|---|
| t1 | Old task | Backlog | Product Plan | Found by t0: the upload retry never stops |
MD
printf 'Found by t1: the upload retry never stops.\n' > found.md
