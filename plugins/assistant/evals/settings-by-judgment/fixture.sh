#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh prints `<id>-<what>=…` for the project config reference, every file the plugin
# ships outside evals/, and SKILL.md.
set -euo pipefail
cat > check.sh <<'SH'
root=$1
n() { tr -s ' \n' ' ' < "$1"; }
# S16: the fields in the reference's config block, sorted.
echo "s16-fields=$(sed -n '/^```/,/^```/p' "$root/skills/assistant/references/project.md" | grep -oE '^[a-z_]+:' | tr -d : | sort | paste -sd ' ' -)"
# S17: a removed field (as a config line or in backticks), the intake command or its script.
pats=('(^|`)coverage:' '(^|`)render:' '(^|`)analytics:' 'asst-intake' 'intake\.sh')
hits=0
for p in "${pats[@]}"; do
  while read -r f; do [ -n "$f" ] && { echo "s17-hit: $p in ${f#"$root"/}"; hits=$((hits + 1)); }
  done <<<"$(find "$root" -mindepth 1 -maxdepth 1 ! -name evals -exec grep -rlE -- "$p" {} + 2>/dev/null)"
done
echo "s17-hits=$hits"
[ -e "$root/bin/asst-intake" ]; echo "s17-bin=$?"
# S18: SKILL.md — no fixed module list, the model finds the commands, analytics from CLAUDE.md.
s=$(n "$root/skills/assistant/SKILL.md")
echo "s18-modules=$(grep -ciE 'frontend[^.]{0,20}backend[^.]{0,20}product|five modules' <<<"$s")"
echo "s18-coverage=$(grep -ciE 'find[^.]{0,60}coverage[^.]{0,60}command|coverage command[^.]{0,100}(find|CLAUDE\.md|CI config)' <<<"$s")"
echo "s18-render=$(grep -ciE 'find[^.]{0,60}(screenshot|render)[^.]{0,60}command|(screenshot|render) command[^.]{0,100}(find|CLAUDE\.md|CI config)' <<<"$s")"
echo "s18-analytics=$(grep -ciE 'analytics[^.]{0,160}CLAUDE\.md|CLAUDE\.md[^.]{0,160}(analytics|BigQuery)' <<<"$s")"
SH
