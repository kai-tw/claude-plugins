#!/bin/bash
# cloud-setup v1 — bump this number after merging a change to scripts/cloud-setup.sh
#
# The whole content of the environment's "Setup script" field (claude.ai →
# Settings → Claude Code → the environment). It fetches and runs
# scripts/cloud-setup.sh from main, so that file is never pasted: a 400-line
# paste arrived cut off at line ~101 and the session failed to start.
#
# The snapshot rebuilds only when THIS text changes, never when the fetched file
# does — so after merging a change there, bump the number above and paste this
# again. Downloaded to a file and checked before running: `curl | bash` on a
# failed download runs an empty script, exits 0, and starts a session with
# nothing installed and nothing said.
f=$(mktemp)
if curl -fsSL --retry 3 https://raw.githubusercontent.com/kai-tw/claude-plugins/main/scripts/cloud-setup.sh -o "$f" && [ -s "$f" ]; then
  bash "$f"
else
  mkdir -p ~/.claude && printf '\n## This environment is INCOMPLETE\n\nscripts/cloud-setup.sh could not be downloaded, so nothing was installed: no Flutter, no plugins, no ntn. Say so before doing any work.\n' >> ~/.claude/CLAUDE.md
fi
exit 0
