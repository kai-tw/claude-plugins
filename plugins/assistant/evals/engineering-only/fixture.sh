#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh is written to a scratch dir, not the case folder, so a run leaves nothing in the repo.
# It prints `<id>-<what>=…` for SKILL.md, references/brief.md and every file under skills/ and agents/.
set -euo pipefail
dir="${TMPDIR:-/tmp}/engineering-only-eval"
mkdir -p "$dir"
cat > "$dir/check.sh" <<'SH'
root=$1
n() { tr -s ' \n' ' ' < "$1"; }
s=$(n "$root/skills/assistant/SKILL.md")
r=$(n "$root/skills/assistant/references/brief.md")
sr="$s $r"
# S30: no product KB module; no spec-page writing step; SKILL.md calls the spec pages read-only and quoted.
echo "s30-module-file=$([ -e "$root/skills/assistant/references/kb/product.md" ] && echo 1 || echo 0)"
echo "s30-refs=$(grep -rliE 'kb/product|product module|Module=<product|features/<feature>|shared designs?' "$root/skills" "$root/agents" 2>/dev/null | wc -l | tr -d ' ')"
echo "s30-readonly=$(grep -ciE 'spec[^.]{0,120}read-only|read-only[^.]{0,120}spec' <<<"$s")"
echo "s30-quoted=$(grep -ciE 'spec[^.]{0,160}quot|quot[^.]{0,160}spec' <<<"$s")"
# S31: an undecided cell or a spec that conflicts with the code is a Needs you line with a concrete example; the assistant never writes the rule.
echo "s31-needs-you=$(grep -ciE '(spec|case table)[^.]{0,250}(conflict|contradict|disagree|doesn.t decide|does not decide|silent|undecided|leaves? [^.]{0,20}open)[^.]{0,250}Needs you|Needs you[^.]{0,250}(spec)' <<<"$sr")"
echo "s31-example=$(grep -ciE '(spec|conflict|decide)[^.]{0,250}(concrete|example)|(concrete|example)[^.]{0,250}(spec|conflict|decide)' <<<"$sr")"
echo "s31-product-side=$(grep -ciE 'product (side|team|owner|people)|settled with' <<<"$sr")"
echo "s31-never-writes=$(grep -ciE '(never|not|n.t)[^.]{0,40}(write|writes|writing|draft|drafts|invent|invents)[^.]{0,40}(the rule|a rule|product rule|the spec)' <<<"$sr")"
# S32: the decisions the assistant files are engineering decisions; a product behaviour changes only through the spec page.
echo "s32-engineering=$(grep -ciE 'engineering decisions?' <<<"$s")"
echo "s32-spec-only=$(grep -ciE 'product behaviou?r[^.]{0,150}(only|solely)[^.]{0,100}spec|(only|solely)[^.]{0,60}spec[^.]{0,100}product behaviou?r' <<<"$s")"
SH
