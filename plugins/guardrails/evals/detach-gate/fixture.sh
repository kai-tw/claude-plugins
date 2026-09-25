#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh feeds detach-gate.sh detaching and healthy commands and prints each exit code.
set -euo pipefail
cat > check.sh <<'SH'
root=$1
run() { jq -n --arg c "$2" '{tool_input:{command:$c}}' | bash "$root/hooks/detach-gate.sh" 2>/dev/null; echo "$1=$?"; }
run bad-nohup   'cd /repo && nohup plan-mutation -- flutter test test/a > /tmp/m.log 2>&1 & disown'
run bad-amp     'plan-mutation -- flutter test > m.log 2>&1 & echo $!'
run bad-trail   'npm run dev &'
run bad-setsid  'setsid ./server.sh'
run ok-redirect 'flutter test > out.log 2>&1; echo done >&2'
run ok-and      'git fetch && git status'
run ok-waited   'a.sh & b.sh & wait'
run ok-message  'git commit -m "guardrails: ban nohup and a trailing &"'
run ok-heredoc  $'git commit -F - <<\'EOF\'\nnohup x & disown must not appear again\nEOF'
SH
