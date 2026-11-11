#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# `proj` has an assistant project config, `other` doesn't; check.sh feeds the
# hook a prompt from each, and from a subdirectory of `proj`.
set -euo pipefail
mkdir -p proj/.claude proj/lib other
echo 'rules: none' > proj/.claude/assistant.md
cat > check.sh <<'SH'
run() { printf '{"session_id":"s","cwd":"%s","prompt":"fix the login bug"}' "$2" \
  | bash "$1/hooks/flow-reminder.sh"; }
echo "proj=$(run "$1" "$PWD/proj" | jq -c '[.hookSpecificOutput.hookEventName, (.hookSpecificOutput.additionalContext | test("load the `assistant` skill") and test("Don.t edit the project.s code yourself"))]')"
echo "sub=$(run "$1" "$PWD/proj/lib" | jq -c '[.hookSpecificOutput.hookEventName]')"
echo "other=[$(run "$1" "$PWD/other")]"
SH
