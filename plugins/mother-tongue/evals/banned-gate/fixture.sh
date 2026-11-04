#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh feeds stop.sh three replies and prints what it says to each.
set -euo pipefail
mkdir -p t
cat > check.sh <<'SH'
root=$1
run() { jq -n --arg m "$1" '{session_id:"s",stop_hook_active:false,last_assistant_message:$m}' \
  | TMPDIR="$PWD/t" bash "$root/hooks/stop.sh"; }
echo "en=[$(run 'The push-gate stops the merge until CI is graded green, so wait for the run to finish before you push again.' | jq -r .reason)]"
echo "kept=[$(run 'Watergate is a scandal, not a hook. The `commit-gate` name is gone; the hook is called commit-check now.')]"
echo "zh=[$(run '這個 gate 會先擋下，等 CI 跑完再推。' | jq -r .reason)]"
SH
