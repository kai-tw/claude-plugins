#!/usr/bin/env bash
# A project with an adapter, so asst-strings keys its log on this directory.
set -euo pipefail
git init -q
mkdir -p .claude
touch .claude/assistant.md
