#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh prints `<id>-<what>=…` for the plugin's text and SKILL.md.
set -euo pipefail
cat > check.sh <<'SH'
root=$1
# S5: a removed field, tool or reference named anywhere the plugin ships, evals/ aside.
pats=(base_branch kb_pages device_test ui_strings strings_glossary strings_canon strings_check cloud_fire
  '`devices:' '`features:' '`locales:' '`destructive:' '`check:`' '`gate:' 'asst-pr([^a-z-]|$)' asst-device 'release\.md')
dirs=("$root/.claude-plugin" "$root/agents" "$root/bin" "$root/hooks" "$root/skills"); clean=0
for p in "${pats[@]}"; do
  hits=$(grep -rlE -- "$p" "${dirs[@]}" 2>/dev/null)
  if [ -z "$hits" ]; then clean=$((clean + 1)); else while read -r f; do echo "s5-hit: $p in ${f#"$root"/}"; done <<<"$hits"; fi
done
echo "s5-clean=$clean/${#pats[@]}"
echo "s5-bin=$(ls "$root/bin" | grep -cE '^asst-(pr|device)$')"
# S7: the SKILL.md bullet, step or paragraph that names force-push.
blk=$(awk '/^$|^#|^- |^[0-9]+\. / { if (b ~ /force-push/) { print b; done = 1; exit } b = "" } { b = b " " $0 } END { if (!done && b ~ /force-push/) print b }' "$root/skills/assistant/SKILL.md" | tr -s ' ' ' ')
t() { echo "s7-$1=$(grep -ciE -- "$2" <<<"$blk")"; }
t ask '\bask'; t merge '\bmerg(e|ing)\b'; t default-branch 'default.branch'
t force-push 'force-push'; t delete-branch 'delet(e|es|ing) (a |the )?branch'; t deploy 'deploy'
t user-data 'delet(e|es|ing)[^.]{0,20}user.{0,3} data'; t claude-md 'CLAUDE\.md'; t config 'project config'
SH
