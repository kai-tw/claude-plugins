#!/bin/bash
# cloud-runner-setup v1 — bump this number after merging a change to scripts/cloud-setup.sh,
# scripts/cloud-runner-setup.sh or scripts/cloud-ci-runner.sh
#
# The whole content of the "Setup script" field of the ONE cloud environment
# that runs self-hosted Actions jobs (claude.ai → Settings → Claude Code → that
# environment). Every other Flutter environment keeps cloud-setup-field.sh and
# gets no runner. This runs scripts/cloud-setup.sh first, the same Flutter and
# plugins every environment has, then scripts/cloud-runner-setup.sh, which adds
# the Actions runner and the `cloud-ci-runner` command.
#
# The snapshot rebuilds only when THIS text changes, so bump the number above
# and paste it again after a change to any of the three files.
base=https://raw.githubusercontent.com/kai-tw/claude-plugins/main/scripts
for s in cloud-setup.sh cloud-runner-setup.sh; do
  f=$(mktemp)
  if curl -fsSL --retry 3 "$base/$s" -o "$f" && [ -s "$f" ]; then
    bash "$f"
  else
    mkdir -p ~/.claude && printf '\n## This environment is INCOMPLETE\n\nscripts/%s could not be downloaded, so what it installs is missing. Say so before doing any work.\n' "$s" >> ~/.claude/CLAUDE.md
  fi
done
exit 0
