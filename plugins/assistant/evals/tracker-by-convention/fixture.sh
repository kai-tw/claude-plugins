#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh prints `<id>-<what>=…` for the project config reference, every file the plugin
# ships outside evals/, SKILL.md, and the skill and agent text together.
set -euo pipefail
cat > check.sh <<'SH'
root=$1
n() { tr -s ' \n' ' ' < "$1"; }
# S11: the fields in the reference's config block, sorted.
echo "s11-fields=$(sed -n '/^```/,/^```/p' "$root/skills/assistant/references/project.md" | grep -oE '^[a-z_]+:' | tr -d : | sort | paste -sd ' ' -)"
# S12: the removed tool, its script, or a removed field — as a config line or in backticks.
pats=('asst-board' 'board\.mjs' '(^|`)board:' '(^|`)vcs:' '(^|`)kb:' 'notion_root')
hits=0
for p in "${pats[@]}"; do
  while read -r f; do [ -n "$f" ] && { echo "s12-hit: $p in ${f#"$root"/}"; hits=$((hits + 1)); }
  done <<<"$(find "$root" -mindepth 1 -maxdepth 1 ! -name evals -exec grep -rlE -- "$p" {} + 2>/dev/null)"
done
echo "s12-hits=$hits"
[ -e "$root/bin/asst-board" ]; echo "s12-bin=$?"
# S13: SKILL.md — where tasks live, the vocabulary, the unblock and close-the-parent rules.
s=$(n "$root/skills/assistant/SKILL.md")
blk=$(awk '/^$|^#|^- |^[0-9]+\. / { if (b ~ /convention/) print b; b = "" } { b = b " " $0 } END { if (b ~ /convention/) print b }' "$root/skills/assistant/SKILL.md" | tr -s ' \n' ' ')
t() { echo "s13-$1=$(grep -ciE -- "$2" <<<"$blk")"; }
t claude-md 'CLAUDE\.md'; t ask '\bask'; t once '\bonce\b'; t write '\bwrit(e|es|ing)\b[^.]{0,80}CLAUDE\.md'
miss=
for w in 'In Progress' Next Backlog Deferred 'Product Plan' 'Engineering Plan' 'Design Plan' Implementation Review QA; do
  grep -qF -- "$w" <<<"$s" || miss="$miss,$w"
done
echo "s13-vocab-missing=${miss#,}"
echo "s13-unblock=$(grep -ciE 'last (open |remaining )?blocker[^.]{0,120}In Progress|In Progress[^.]{0,120}last (open |remaining )?blocker' <<<"$s")"
echo "s13-parent=$(grep -ciE 'last (open |remaining )?(sub-item|sub-task|child)[^.]{0,120}parent|parent[^.]{0,120}last (open |remaining )?(sub-item|sub-task|child)' <<<"$s")"
# S14 / S15: the skill and agent text together.
all=$(for f in $(find "$root/skills" "$root/agents" -name '*.md'); do n "$f"; echo; done)
echo "s14-svn=$(grep -ciE '\.svn`?[^;]{0,60}\b(no|without|not)\b[^;]{0,20}`?\.git\b|\b(no|without)\b[^;]{0,20}`?\.git`?[^;]{0,60}\.svn' <<<"$all")"
echo "s14-per-config=$(grep -ciE 'svn[^.]{0,60}per the project config' <<<"$all")"
echo "s15-root=$(grep -cE 'CLAUDE\.md[^.]{0,200}root page|root page[^.]{0,200}CLAUDE\.md' <<<"$all")"
SH
