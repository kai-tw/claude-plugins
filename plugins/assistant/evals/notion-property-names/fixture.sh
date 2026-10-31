#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
set -euo pipefail
mkdir -p .claude
printf '# Decision Log, in the project language\ndecision-log = 決策紀錄\ndecision-log.Feature = 功能\n' > .claude/kb-databases.txt
printf 'decision-log.Task = 任務\n' > bad.txt
