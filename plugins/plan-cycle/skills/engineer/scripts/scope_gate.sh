#!/usr/bin/env bash
# Scope-gate — read the plan's own tables and say whether engineer-plan-reviewer
# has a surface to walk. Its two dimensions ask "should this exist at all"
# (10 abstraction / reuse / ownership · 11 migration & back-compat); everything
# else is graded on the diff by code-reviewer (`notion-payload criteria
# engineering-plan`).
#
# The VERDICT line is the contract review-loop.md acts on:
#   VERDICT: skip-eligible — surface absent    no spawn; record it in ## Revision history
#   VERDICT: review — <reasons>                spawn; the reasons are the dimensions
# skip-eligible needs ALL of: §Classes has no (NEW) / (DEL) / pubspec.yaml row and
# every (MOD) row leaves `為何要新增` as `—`; §Migration impact is its one-line
# 無…變更 form; no second-face or migration tell in the text. Any doubt → review.
#
# Usage: scope_gate.sh <engineering-plan.md>
set -uo pipefail

plan="${1:-}"
if [ -z "$plan" ] || [ ! -f "$plan" ]; then
  echo "usage: plan-scope-gate <engineering-plan.md>" >&2
  exit 2
fi

section() { awk -v pat="$1" '/^## /{ if (p) exit; if ($0 ~ pat) { p=1; next } } p' "$plan"; }
classes="$(section '^## .*(Classes|類別)')"
migration="$(section '^## .*(Migration|遷移|相容性|向後相容)')"

reasons=()
grep -qE '\((\*\*)?NEW(\*\*)?\)' <<< "$classes" && reasons+=("§Classes has NEW row(s) → 10")
grep -qE '\((\*\*)?DEL(\*\*)?\)' <<< "$classes" && reasons+=("§Classes has DEL row(s) → 11")
grep -qi 'pubspec\.yaml' <<< "$classes" && reasons+=("pubspec.yaml row → package-explorer pre-pass, then 10")
# A MOD row whose last cell (為何要新增) is not `—` adds a member to a class someone else owns.
mod_answered="$(awk -F'|' '/\((\*\*)?MOD(\*\*)?\)/ { n=NF; while (n>1 && $n ~ /^[ \t]*$/) n--; c=$n; gsub(/[ \t`*]/,"",c); if (c!="—" && c!="-") print $2 }' <<< "$classes")"
[ -n "$mod_answered" ] && reasons+=("MOD row(s) answering 為何要新增 (member added):${mod_answered//$'\n'/ } → 10")
if [ -z "$migration" ]; then
  reasons+=("no §Migration impact section → 11 (fail-closed)")
else
  mig_lines="$(grep -vE '^[[:space:]]*$|^<' <<< "$migration")"
  { [ "$(grep -c . <<< "$mig_lines")" -eq 1 ] && grep -qE '^無.*變更' <<< "$mig_lines"; } \
    || reasons+=("§Migration impact has content → 11")
fi
grep -qiE 'projected from|derived from|mirrors' "$plan" \
  && reasons+=("second-face tell (projected/derived/mirrors) → 10")
grep -qiE 'schemaVersion|persisted.?schema|VersionedJson|metadata\.json|changed.*signature|wrapper.*delet' "$plan" \
  && reasons+=("migration tell → 11")

if [ ${#reasons[@]} -eq 0 ]; then
  echo "VERDICT: skip-eligible — surface absent (no NEW/DEL/pubspec row, MOD rows add no member, §Migration impact 無變更, no tell)"
else
  echo "VERDICT: review —"
  printf '  - %s\n' "${reasons[@]}"
fi
echo "Security / privacy: not gated here — they read the diff's real sinks (plan/SKILL.md §audit matrix)."
