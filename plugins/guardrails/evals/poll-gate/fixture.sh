#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh feeds poll-gate.sh polling and healthy commands and prints each exit code.
set -euo pipefail
cat > check.sh <<'SH'
root=$1
run() { jq -n --arg c "$2" '{tool_input:{command:$c}}' | bash "$root/hooks/poll-gate.sh" 2>/dev/null; echo "$1=$?"; }
run bad-checks  'cd repo && gh pr checks 16 --watch --interval 15 2>&1 | tail -2'
run bad-run     'gh run watch 35951964873'
run bad-watch   'watch -n 5 git status'
run bad-until   'until gh run view 1 --json status | grep -q completed; do sleep 30; done'
run bad-while   $'while true\ndo\n  curl -s localhost:3000 && break\n  sleep 1\ndone'
run ok-checks   'gh pr checks 16'
run ok-builder  'dart run build_runner watch'
run ok-for      'for f in *.md; do wc -l "$f"; done'
run ok-message  'git commit -m "guardrails: ban gh pr checks --watch and sleep loops"'
run ok-heredoc  $'git commit -F - <<\'EOF\'\nwhile true; do sleep 5; done must not appear again\nEOF'
SH
