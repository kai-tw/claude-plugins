#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh feeds remind.sh one zh-TW prompt and prints the rules it attaches.
set -euo pipefail
mkdir -p t
cat > check.sh <<'SH'
root=$1
jq -n '{session_id:"s",prompt:"幫我看一下這個 plugin 為什麼裝不起來。"}' \
  | TMPDIR="$PWD/t" bash "$root/hooks/remind.sh" | jq -r .hookSpecificOutput.additionalContext
SH
