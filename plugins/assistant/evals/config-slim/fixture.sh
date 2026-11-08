#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# A file-board project whose config still carries fields the plugin no longer reads, and
# check.sh, which prints `<id>-<what>=…` for the project config reference, the plugin's text and SKILL.md.
set -euo pipefail
mkdir -p .claude
printf 'vcs: git\nboard: file\nkb: docs/kb\nkb_pages: product\nbase_branch: staging\ndevice_test: flutter test integration_test -d {device}\ndevices: android ios\nfeatures: docs/features.md\nui_strings: lib/l10n/*.arb\nlocales: en → zh-TW\ndestructive: svn commit\ngate: npm test\n' > .claude/assistant.md
cp .claude/assistant.md config.before
printf '# Dark mode\n\n### palette\n**Context** c\n**Decision** d\n**Consequence** e\n' > nopages.md
cat > check.sh <<'SH'
root=$1
# S4: the fields in the reference's config block, sorted.
echo "s4-fields=$(sed -n '/^```/,/^```/p' "$root/skills/assistant/references/project.md" | grep -oE '^[a-z_]+:' | tr -d : | sort | paste -sd ' ' -)"
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
# S6 / B4: decide on a file board, the config still naming kb_pages and the other removed fields.
asst-board decide t1 nopages.md >/dev/null 2>&1; echo "s6-exit=$?"
echo "s6-filed=$(grep -c '^### palette$' docs/kb/decisions/t1.md 2>/dev/null || echo 0)"
asst-board create t2 Name=Two >/dev/null 2>&1 && asst-board list >/dev/null 2>&1; echo "b4-board=$?"
cmp -s config.before .claude/assistant.md; echo "b4-untouched=$?"
# S7: the SKILL.md bullet, step or paragraph that names force-push.
blk=$(awk '/^$|^#|^- |^[0-9]+\. / { if (b ~ /force-push/) { print b; done = 1; exit } b = "" } { b = b " " $0 } END { if (!done && b ~ /force-push/) print b }' "$root/skills/assistant/SKILL.md" | tr -s ' ' ' ')
t() { echo "s7-$1=$(grep -ciE -- "$2" <<<"$blk")"; }
t ask '\bask'; t merge '\bmerg(e|ing)\b'; t default-branch 'push(es|ing)? (to|into|on) the default branch'
t force-push 'force-push'; t delete-branch 'delet(e|es|ing) (a |the )?branch'; t deploy 'deploy'
t user-data 'delet(e|es|ing)[^.]{0,20}user.{0,3} data'; t claude-md 'CLAUDE\.md'; t config 'project config'
SH
