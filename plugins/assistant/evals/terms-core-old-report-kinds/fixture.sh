#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# Reports an older version filed under the kinds scout and build-wire.
set -euo pipefail
mkdir -p .claude/.assistant/reports/t
printf 'vcs: svn\nboard: file\n' > .claude/assistant.md
echo old > .claude/.assistant/reports/t/scout-1.md
echo old > .claude/.assistant/reports/t/build-wire-2.md
