#!/usr/bin/env bash
# The anti-divergence check for a plan review's verification round.
#
# WHAT THIS IS FOR. Re-running a judgment gate produces a NEW judgment, not a
# verification of the old one — `plan/SKILL.md` §Gate loop policy — so a plan
# reviewed that way never closes: it grows new findings every fix. Measured: one
# cycle ran 20 rounds without converging, the findings multiplying each time.
# The verification round closes only because every item is accounted for, and
# accounting is the kind of discipline that quietly lapses under context
# pressure. So it is checked here rather than asked for in prose.
#
# WHAT THIS IS NOT. It does not merge, score, rank or decide. The reviewer walks
# both dimensions in one context and writes its own report; there is no fan-out
# to reconcile and no score to total. (There was: this file used to merge one
# JSON per dimension from one sub-agent per dimension. Both are gone.)
#
# INPUT — one JSON per round, findings in a flat array:
#
#   {"round": 2,
#    "findings": [
#      {"id": "10.1", "dimension": "abstraction", "severity": "critical",
#       "problem": "…", "failure_scenario": "…", "cites": ["§Classes"],
#       "fix": "…"}
#    ]}
#
#   severity        critical | warning | suggestion
#   fix             required on every finding — the one the reviewer would make
#                   (engineer-plan-reviewer.md Iron Law 2), or
#                   `無法判定: <what was searched>`
#   failure_scenario required on critical and warning; a suggestion has none by
#                   definition (nothing is wrong — a better option merely exists)
#   suggestions     capped at 3. Zero is a perfectly good answer.
#
# ON A VERIFICATION ROUND (--prev <the prior round's json>), each finding also
# carries `origin`:
#   prior           still open — cite what in the rev failed to clear it
#   diff-introduced the fix broke it — cite the rev line
#   newly-observed  neither; then `missed_because` must name what the prior
#                   round failed to read. This is the churn gate: the bar for a
#                   finding the prior round did not have is evidence of a MISS,
#                   not a fresh opinion.
# and every prior id must be accounted for — listed as resolved, or carried with
# origin `prior`. An unaccounted prior id is the failure this whole file exists
# to catch.
#
# Usage: plan-converge check <round.json> [--prev <prior.json>]
#        plan-converge prior <prior.json>          # ids for the next brief
# Exit:  0 = accounted for and nothing blocking
#        1 = the accounting does not add up (reason printed)
#        2 = bad usage
#        3 = accounting fine, but a critical finding blocks the plan. Distinct
#            from 1 on purpose: nothing is wrong with the ROUND, the plan is
#            blocked — and a caller reading only the exit code must not take
#            that for a pass (`plan_lint.sh` learned this as `PASS*`).
set -uo pipefail

command -v jq >/dev/null 2>&1 || { echo "plan-converge: jq is required" >&2; exit 2; }

die() { echo "plan-converge: $*" >&2; exit 2; }
fail() { echo "REFUSING — $*"; exit 1; }

cmd="${1-}"; file="${2-}"; prev=""
shift 2 2>/dev/null || true
while [ "$#" -gt 0 ]; do
  case "$1" in
    --prev) prev="${2-}"; [ -n "$prev" ] || die "--prev needs a file"; shift 2 ;;
    *) die "unknown option \"$1\"" ;;
  esac
done

[ -n "$cmd" ] && [ -n "$file" ] || die "usage: plan-converge {check|prior} <round.json> [--prev <prior.json>]"
[ -f "$file" ] || die "no such file: $file"
jq -e . "$file" >/dev/null 2>&1 || die "$file is not valid JSON"
[ -z "$prev" ] || [ -f "$prev" ] || die "no such file: $prev"

ids_of() { jq -r '.findings[]? | .id // empty' "$1"; }

if [ "$cmd" = "prior" ]; then
  jq -r '.findings[]? | "\(.id)\t\(.severity)\t\(.dimension)\t\(.problem)"' "$file"
  exit 0
fi
[ "$cmd" = "check" ] || die "unknown command \"$cmd\""

# ── shape ────────────────────────────────────────────────────────────────────
bad="$(jq -r '
  [ .findings[]? |
    select(
      ((.id // "") == "") or ((.dimension // "") == "") or
      ((.problem // "") == "") or ((.fix // "") == "") or
      (((.severity // "") | IN("critical","warning","suggestion")) | not) or
      (((.severity // "") | IN("critical","warning")) and ((.failure_scenario // "") == ""))
    ) | .id // "(no id)" ] | join(", ")' "$file")"
[ -z "$bad" ] || fail "malformed finding(s): ${bad}
  every finding needs id · dimension · severity (critical|warning|suggestion) ·
  problem · fix; critical and warning also need failure_scenario."

dupes="$(ids_of "$file" | sort | uniq -d | tr '\n' ' ')"
[ -z "${dupes// /}" ] || fail "duplicate finding id(s): ${dupes}"

n_sugg="$(jq -r '[.findings[]? | select(.severity == "suggestion")] | length' "$file")"
[ "$n_sugg" -le 3 ] || fail "${n_sugg} suggestions — the cap is 3, ranked by value.
  A suggestion is only a finding when the better option ALREADY EXISTS; an
  uncertain defect is a warning with the doubt stated, never a demotion to here."

# ── verification-round accounting ────────────────────────────────────────────
if [ -n "$prev" ]; then
  jq -e . "$prev" >/dev/null 2>&1 || die "$prev is not valid JSON"

  bad_origin="$(jq -r '
    [ .findings[]? |
      select(
        (((.origin // "") | IN("prior","diff-introduced","newly-observed")) | not) or
        ((.origin == "newly-observed") and ((.missed_because // "") == ""))
      ) | .id ] | join(", ")' "$file")"
  [ -z "$bad_origin" ] || fail "on a verification round every finding needs an origin
  (prior | diff-introduced | newly-observed), and newly-observed needs
  missed_because — naming what the prior round failed to read. Offending: ${bad_origin}"

  resolved="$(jq -r '[.resolved[]?] | join("\n")' "$file")"
  carried="$(jq -r '[.findings[]? | select(.origin == "prior") | .id] | join("\n")' "$file")"
  unaccounted=""
  while IFS= read -r pid; do
    [ -n "$pid" ] || continue
    grep -qxF "$pid" <<< "$resolved" && continue
    grep -qxF "$pid" <<< "$carried" && continue
    unaccounted="${unaccounted}${pid} "
  done <<< "$(ids_of "$prev")"
  [ -z "$unaccounted" ] || fail "prior finding(s) neither resolved nor carried: ${unaccounted}
  Every prior id must appear in .resolved[] or as a finding with origin \"prior\".
  Silently dropping one is how a round becomes a fresh review instead of a
  verification — and a fresh review never closes."

  # A regression is severity-shaped now, not score-shaped: a dimension that had
  # no critical last round and has one now.
  regressed="$(jq -rn --slurpfile a "$prev" --slurpfile b "$file" '
    ($a[0].findings // []) as $p | ($b[0].findings // []) as $c |
    [ $c[] | select(.severity == "critical") | .dimension ] -
    [ $p[] | select(.severity == "critical") | .dimension ] | unique | join(", ")')"
  [ -z "$regressed" ] && regressed="(none)"

  echo "CONVERGENCE"
  echo "  prior findings   $(ids_of "$prev" | grep -c . || true)"
  echo "  resolved         $(jq -r '[.resolved[]?] | length' "$file")"
  echo "  still open       $(jq -r '[.findings[]? | select(.origin == "prior")] | length' "$file")"
  echo "  diff-introduced  $(jq -r '[.findings[]? | select(.origin == "diff-introduced")] | length' "$file")"
  echo "  newly-observed   $(jq -r '[.findings[]? | select(.origin == "newly-observed")] | length' "$file")"
  echo "  REGRESSION       ${regressed}"
  echo "    (a dimension with no critical last round and one now — answer it in"
  echo "     §Observations: real re-break, or re-derivation artefact?)"
  echo
fi

# ── verdict ──────────────────────────────────────────────────────────────────
n_crit="$(jq -r '[.findings[]? | select(.severity == "critical")] | length' "$file")"
n_warn="$(jq -r '[.findings[]? | select(.severity == "warning")] | length' "$file")"

echo "FINDINGS  ${n_crit} critical · ${n_warn} warning · ${n_sugg} suggestion"
if [ "$n_crit" -gt 0 ]; then
  echo "VERDICT   blocked — ${n_crit} critical finding(s) must be resolved before this plan proceeds."
  exit 3
else
  echo "VERDICT   proceed — no critical findings."
  echo "          Warnings do not loop: apply each fix, or record it as accepted"
  echo "          debt in one line of the report (plan/SKILL.md §Gate loop policy)."
fi
exit 0
