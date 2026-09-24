#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# A repo on `main`, and check.sh, which feeds push-gate.sh four push commands
# under /bin/bash (3.2 on macOS) and prints each exit code.
set -euo pipefail
git init -q -b main repo
git -C repo -c user.name=e -c user.email=e@e commit -q --allow-empty -m init
cat > check.sh <<'SH'
root=$1
run() { jq -n --arg c "$1" --arg d "$PWD/repo" '{tool_input:{command:$c},cwd:$d}' \
  | /bin/bash "$root/hooks/push-gate.sh" 2>/dev/null; echo $?; }
echo "bare=$(run 'git push --force')"
echo "named=$(run 'git push --force origin main')"
echo "chained=$(run 'git status && git push -f origin main')"
echo "branch=$(run 'git push --force origin feature')"
SH
