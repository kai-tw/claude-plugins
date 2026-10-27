#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
set -euo pipefail
git init -q
mkdir -p .claude shots
touch .claude/assistant.md
# States that are not empty / loading / error / populated, in two locales (one with a dash),
# plus a screen whose name holds a dash.
png=iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==
for n in key_rejected-retrying-zh-TW key_rejected-failed-zh-TW key_rejected-retrying-en sign-in-offline-zh-TW; do
  base64 -d <<<"$png" > "shots/$n.png"
done
