#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh prints `s36-hit: …` for every removed name and every removed file still present,
# `s36-hits=<n>`, then the verifier, SKILL.md and delivery-summary text for the graders to read.
set -euo pipefail
cat > check.sh <<'SH'
root=$1
n() { tr -s ' \n' ' ' < "$1"; }
pat='ui-text-pack|asst-strings|verify-text|house-style|asst-analytics|analytics\.(md|mjs)'
hits=0
while read -r f; do
  [ -n "$f" ] && { echo "s36-hit: name in ${f#"$root"/}"; hits=$((hits + 1)); }
done <<<"$(find "$root" -mindepth 1 -maxdepth 1 ! -name evals -exec grep -rlE -- "$pat" {} + 2>/dev/null)"
while read -r f; do
  [ -n "$f" ] && { echo "s36-hit: file ${f#"$root"/}"; hits=$((hits + 1)); }
done <<<"$(find "$root" -path "$root/evals" -prune -o \( -iname '*ui-text-pack*' -o -iname '*asst-strings*' -o -iname '*verify-text*' -o -iname '*house-style*' -o -iname '*asst-analytics*' -o -iname 'analytics.md' -o -iname 'analytics.mjs' \) -print 2>/dev/null)"
echo "s36-hits=$hits"
echo "--- agents/verifier.md"; n "$root/agents/verifier.md"; echo
echo "--- skills/assistant/SKILL.md"; n "$root/skills/assistant/SKILL.md"; echo
echo "--- skills/assistant/references/delivery-summary.md"; n "$root/skills/assistant/references/delivery-summary.md"; echo
SH
