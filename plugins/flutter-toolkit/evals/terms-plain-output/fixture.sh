#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh prints what the model reads from this plugin: every skill and reference
# file and the plugin description. Paths are globbed, never named, so the case checks
# any version's files rather than finding none.
set -euo pipefail
cat > check.sh <<'SH'
root=$1
n=0
for f in "$root"/skills/*/SKILL.md "$root"/skills/*/references/*.md; do
  [ -f "$f" ] || continue
  cat "$f"; n=$((n + 1))
done
echo "skill-files=$n"
jq -r .description "$root/.claude-plugin/plugin.json"
SH
