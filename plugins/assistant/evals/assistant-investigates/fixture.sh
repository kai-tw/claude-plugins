#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh prints `<id>-<what>=…` for SKILL.md, references/brief.md, agents/builder.md,
# agents/tester.md and agents/verifier.md.
set -euo pipefail
cat > check.sh <<'SH'
root=$1
n() { tr -s ' \n' ' ' < "$1"; }
s=$(n "$root/skills/assistant/SKILL.md")
r=$(n "$root/skills/assistant/references/brief.md")
fi=$(n "$root/skills/assistant/forms/investigation.md")
b=$(n "$root/agents/builder.md")
t=$(n "$root/agents/tester.md")
v=$(n "$root/agents/verifier.md")
# S27: no builder investigation phase; SKILL.md has the assistant run and file it itself.
echo "s27-builder-phase=$(grep -ciE '^- \*\*investigation\*\*|phases?[^.]{0,80}investigation|investigation[^.]{0,40}phase|investigation before' "$root/agents/builder.md")"
echo "s27-skill-dispatch=$(grep -ciE 'investigation ·|builder[^.]{0,40}phase `?investigation|phase `?investigation' <<<"$s")"
echo "s27-skill-itself=$(grep -ciE '\*\*Investigation\*\* \((you|the assistant)\)' <<<"$s")"
echo "s27-skill-put=$(grep -ciE 'asst-report put[^.]{0,40}investigation' <<<"$s")"
# S28: case table in forms/investigation.md and references/brief.md.
echo "s28-skill=$(grep -ciE 'case table[^.]{0,250}(combination|interleav)|(combination|interleav)[^.]{0,250}case table' <<<"$fi")"
echo "s28-brief=$(grep -ciE 'case table[^.]{0,250}(combination|interleav|spec|file:line)|(combination|interleav)[^.]{0,250}case table' <<<"$r")"
echo "s28-columns=$(grep -ciE 'case table[^.]{0,250}(base|before)[^.]{0,200}(spec|rule)[^.]{0,200}(after|change)' <<<"$s $r")"
# S29: tester a test per cell; verifier checks every fix round against the whole table.
echo "s29-tester=$(grep -ciE 'case table[^.]{0,200}(cell|combination)[^.]{0,120}test|test[^.]{0,120}(each|every|per)[^.]{0,40}(cell|combination)[^.]{0,120}case table|(cell|combination)[^.]{0,80}case table[^.]{0,120}test|(each|every|per)[^.]{0,30}cell[^.]{0,60}test' <<<"$t")"
echo "s29-verifier=$(grep -ciE 'fix round[^.]{0,200}(whole|entire|full|every)[^.]{0,60}case table|case table[^.]{0,200}(every|each) fix round|(whole|entire|full) case table[^.]{0,200}fix|(every|each) fix round[^.]{0,200}case table' <<<"$v")"
SH
