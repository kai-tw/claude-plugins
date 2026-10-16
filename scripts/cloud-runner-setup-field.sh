#!/bin/bash
# cloud-runner-setup v2 — bump this number to rebuild the environment
for s in cloud-setup.sh cloud-runner-setup.sh; do
  f=$(mktemp)
  if curl -fsSL https://raw.githubusercontent.com/kai-tw/claude-plugins/main/scripts/$s -o "$f" && [ -s "$f" ]; then
    bash "$f"
  else
    mkdir -p ~/.claude && printf '\n## This environment is INCOMPLETE\n\n%s could not be downloaded, so what it installs is missing. Say so before doing any work.\n' "$s" >> ~/.claude/CLAUDE.md
  fi
done
exit 0
