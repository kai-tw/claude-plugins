#!/usr/bin/env bash
# Dimension-report join + merge for `blueprint-reviewer`'s fan-out.
#
# WHY THIS EXISTS
#   The reviewer dispatches one sub-agent per dimension batch. Those children
#   report to a FILE, not to the reviewer: measured across 19 fan-out reviews,
#   84 children were spawned and 2 results ever came back — a nested `Agent`
#   call returns `Async agent launched successfully.` and nothing else. Without
#   a file join the reviewer has no way to know a child finished, so it burned
#   36 improvised `Bash` sleeps waiting, gave up 3 minutes before the last child
#   landed, scored the rest itself off 9 file reads, and published a report with
#   6 of 12 dimensions marked `not scored`. An earlier round did the worse
#   thing and invented the missing scores outright.
#
#   So the join is mechanical here, and a hole is an EXIT CODE rather than a
#   sentence in the report. What the reviewer cannot see, it cannot summarise,
#   and what never landed, it cannot invent.
#
# THE FILE CONTRACT
#   One JSON file per dimension in <dir> (any *.json name; the `criterion`
#   field is the key):
#     {"criterion": 7, "dimension": "error-handling", "score": 5,
#      "cites": ["§Error policy"],
#      "weaknesses": [{"problem": "…", "failure_scenario": "…",
#                      "severity": "blocking"}]}
#   `dimension` must equal this script's canonical slug for that criterion —
#   that is the dispatch echo-back, checked mechanically instead of by eye, so a
#   child briefed for coupling that scored testability is rejected, not merged.
#   `weaknesses` is required when score < 8 (a sub-8 with no named weakness is
#   not a finding), and `severity` must be `blocking` when score < 6.
#
# Usage:
#   blueprint_merge.sh wait   <dir> --criteria 1,5,6,7 [--timeout 480]
#   blueprint_merge.sh report <dir> --criteria 1,5,6,7 [--prev <dir>]
#
# Exit: 0 = every expected criterion present and valid, 1 = missing / invalid
#       (named on stdout), 2 = bad usage or no jq.
#
# THE VERDICT IS NOT THE EXIT CODE — deliberate. `report` exits 0 for a plan it
# sends back to revise: 0 means "the report is complete", not "the plan passed".
# Gate the plan on the `VERDICT:` line, gate the round on the exit code.
set -uo pipefail

canonical_slug() {
  case "$1" in
    1) echo time ;;      2) echo space ;;       3) echo scalability ;;
    4) echo extendability ;; 5) echo coupling ;; 6) echo correctness ;;
    7) echo error-handling ;; 8) echo package ;; 9) echo testability ;;
    10) echo abstraction ;; 11) echo migration ;; 12) echo startup ;;
    *) return 1 ;;
  esac
}

canonical_name() {
  case "$1" in
    1) echo "Time complexity" ;;   2) echo "Space complexity" ;;
    3) echo "Scalability" ;;       4) echo "Extendability" ;;
    5) echo "Low coupling" ;;      6) echo "Design correctness" ;;
    7) echo "Runtime error handling" ;; 8) echo "Package usage" ;;
    9) echo "Testability" ;;      10) echo "Abstraction/reuse/ownership" ;;
    11) echo "Migration & back-compat" ;; 12) echo "Startup & init order" ;;
    *) return 1 ;;
  esac
}

die() { printf '%s\n' "$*" >&2; exit 2; }

command -v jq >/dev/null 2>&1 || die "blueprint-merge: jq not found — it is the parser, not a nicety."

cmd=${1-}; dir=${2-}
[ -n "$cmd" ] && [ -n "$dir" ] || die "Usage: blueprint_merge.sh {wait|report} <dir> --criteria <csv> [--timeout <sec>] [--prev <dir>]"
shift 2

criteria=""; timeout=480; prev=""
while [ $# -gt 0 ]; do
  case "$1" in
    --criteria) criteria=${2-}; shift 2 ;;
    --timeout)  timeout=${2-}; shift 2 ;;
    --prev)     prev=${2-}; shift 2 ;;
    *) die "blueprint-merge: unknown argument '$1'" ;;
  esac
done
[ -n "$criteria" ] || die "blueprint-merge: --criteria is required (the in-scope set from the scope-gate)."
[ -d "$dir" ] || die "blueprint-merge: '$dir' is not a directory."

IFS=',' read -r -a want <<< "$criteria"
for c in "${want[@]}"; do
  canonical_slug "$c" >/dev/null 2>&1 || die "blueprint-merge: '$c' is not a criterion number (1–12)."
done

# ---------------------------------------------------------------------------
# scan: fills found[criterion]=file, bad[criterion]=reason for one pass over dir
# (indexed by criterion number — bash 3.2 ships on macOS and has no `declare -A`)
# ---------------------------------------------------------------------------
found=(); bad=(); filebad=""
scan() {
  found=(); bad=(); filebad=""
  local f crit slug score
  for f in "$dir"/*.json; do
    [ -e "$f" ] || continue
    if ! jq -e . "$f" >/dev/null 2>&1; then
      filebad="$filebad$(basename "$f") — not valid JSON (still being written, or truncated)"$'\n'
      continue
    fi
    crit=$(jq -r '.criterion // empty' "$f")
    case "$crit" in ''|*[!0-9]*) filebad="$filebad$(basename "$f") — no integer .criterion"$'\n'; continue ;; esac
    slug=$(canonical_slug "$crit" 2>/dev/null) || { filebad="$filebad$(basename "$f") — criterion $crit out of range"$'\n'; continue; }

    if [ -n "${found[$crit]-}" ]; then
      bad[$crit]="two files claim criterion $crit ($(basename "${found[$crit]}") and $(basename "$f"))"
      continue
    fi

    local reason=""
    [ "$(jq -r '.dimension // empty' "$f")" = "$slug" ] \
      || reason="dispatch drift — .dimension is '$(jq -r '.dimension // "(absent)"' "$f")', criterion $crit is '$slug'"
    score=$(jq -r '.score // empty' "$f")
    case "$score" in ''|*[!0-9]*) [ -n "$reason" ] || reason="no integer .score" ;; esac
    if [ -z "$reason" ] && { [ "$score" -lt 1 ] || [ "$score" -gt 10 ]; }; then
      reason="score $score outside 1–10"
    fi
    if [ -z "$reason" ] && [ "$(jq -r '[.cites[]? | select(. != "")] | length' "$f")" -lt 1 ]; then
      reason="no .cites — a score with no citation is a guess"
    fi
    if [ -z "$reason" ]; then
      local nw
      nw=$(jq -r '.weaknesses | length' "$f" 2>/dev/null || echo 0)
      if [ "$score" -lt 8 ] && [ "$nw" -lt 1 ]; then
        reason="score $score is sub-8 with no .weaknesses"
      elif [ "$nw" -gt 0 ] && [ "$(jq -r '[.weaknesses[] | select((.problem // "") == "" or (.failure_scenario // "") == "" or ((.severity // "") | IN("blocking","weakness") | not))] | length' "$f")" -gt 0 ]; then
        reason="a weakness is missing .problem / .failure_scenario, or .severity is not blocking|weakness"
      elif [ "$score" -lt 6 ] && [ "$(jq -r '[.weaknesses[] | select(.severity == "blocking")] | length' "$f")" -lt 1 ]; then
        reason="score $score is sub-6 but no weakness is marked blocking"
      fi
    fi

    if [ -n "$reason" ]; then bad[$crit]="$reason"; else found[$crit]="$f"; fi
  done
}

missing_list() {
  local c out=""
  for c in "${want[@]}"; do
    { [ -n "${found[$c]-}" ] || [ -n "${bad[$c]-}" ]; } && continue
    out="$out $c:$(canonical_slug "$c")"
  done
  printf '%s' "${out# }"
}

report_holes() {
  local miss=$1 c
  [ -n "$miss" ] && printf 'MISSING (%s): %s\n' "$(printf '%s' "$miss" | wc -w | tr -d ' ')" "$miss"
  for c in "${want[@]}"; do
    [ -n "${bad[$c]-}" ] && printf 'INVALID  %s:%s — %s\n' "$c" "$(canonical_slug "$c")" "${bad[$c]}"
  done
  [ -n "$filebad" ] && printf 'INVALID  %s' "$filebad"
  return 0
}

# An out-of-scope criterion's file is ignored; an unparseable one is fail-closed
# (no readable `criterion`, so it may well be the in-scope one still landing).
holes() {
  local c
  [ -n "$1" ] && return 0
  [ -n "$filebad" ] && return 0
  for c in "${want[@]}"; do [ -n "${bad[$c]-}" ] && return 0; done
  return 1
}

# ---------------------------------------------------------------------------
case "$cmd" in
wait)
  case "$timeout" in ''|*[!0-9]*) die "blueprint-merge: --timeout takes seconds." ;; esac
  waited=0
  while :; do
    scan
    miss=$(missing_list)
    if ! holes "$miss"; then
      printf 'ALL %d dimensions landed and validated (%ds).\n' "${#want[@]}" "$waited"
      exit 0
    fi
    [ "$waited" -ge "$timeout" ] && break
    sleep 5; waited=$((waited + 5))
  done
  printf 'TIMEOUT after %ds — %d of %d landed.\n' "$waited" "${#found[@]}" "${#want[@]}"
  report_holes "$miss"
  printf '\nRe-dispatch ONLY the names above, then run this again. Do not score them\nyourself and do not publish a report while any line above stands.\n'
  exit 1
  ;;

report)
  scan
  miss=$(missing_list)
  if holes "$miss"; then
    printf 'REFUSING to merge — the dimension set is incomplete.\n'
    report_holes "$miss"
    exit 1
  fi

  pscore=()
  if [ -n "$prev" ]; then
    for f in "$prev"/*.json; do
      [ -e "$f" ] || continue
      jq -e . "$f" >/dev/null 2>&1 || continue
      c=$(jq -r '.criterion // empty' "$f"); s=$(jq -r '.score // empty' "$f")
      case "$c$s" in ''|*[!0-9]*) continue ;; esac
      pscore[$c]="$s"
    done
  fi

  total=0; sub8=0; sub6=0; regressed=""
  dcol=""; dsep=""
  [ -n "$prev" ] && { dcol=' Δ |'; dsep='---|'; }
  printf '## Scores\n\n| # | Criterion | Score | Cites |%s\n' "$dcol"
  printf '|---|---|---|---|%s\n' "$dsep"
  for c in $(printf '%s\n' "${want[@]}" | sort -n); do
    f=${found[$c]}
    s=$(jq -r '.score' "$f")
    cites=$(jq -r '[.cites[]] | join(" · ")' "$f")
    total=$((total + s))
    [ "$s" -lt 8 ] && sub8=$((sub8 + 1))
    [ "$s" -lt 6 ] && sub6=$((sub6 + 1))
    delta=""
    if [ -n "$prev" ]; then
      p=${pscore[$c]-}
      if [ -z "$p" ]; then delta=' — |'
      elif [ "$p" -ge 8 ] && [ "$s" -lt 8 ]; then
        delta=" **$p → $s REGRESSION** |"; regressed="$regressed $c:$(canonical_slug "$c")"
      elif [ "$s" -lt "$p" ]; then delta=" $p → $s ↓ |"
      elif [ "$s" -gt "$p" ]; then delta=" $p → $s ↑ |"
      else delta=" $p → $s = |"; fi
    fi
    printf '| %s | %s | **%s**/10 | %s |%s\n' "$c" "$(canonical_name "$c")" "$s" "$cites" "$delta"
  done
  printf '| | **Total (informational; the gate is per-dimension ≥ 8)** | **%d/%d** | |%s\n\n' \
    "$total" "$((${#want[@]} * 10))" "${dcol:+ |}"

  if [ "$sub6" -gt 0 ]; then verdict="send back to revise — $sub6 dimension(s) below 6"
  elif [ "$sub8" -gt 0 ]; then verdict="approve-with-improvements — $sub8 dimension(s) at 6–7"
  else verdict="approve — every in-scope dimension ≥ 8"; fi
  printf 'VERDICT: %s\n' "$verdict"
  [ -n "$regressed" ] && printf 'REGRESSION: passed last round, sub-8 now —%s. A dimension that was\nfixed and came back is a re-derivation artefact or a real re-break; say which.\n' "$regressed"
  printf '\n'

  if [ "$sub8" -gt 0 ]; then
    printf '## Weaknesses (ascending score — every one blocks `approve`)\n\n'
    for c in $(for k in "${want[@]}"; do printf '%s %s\n' "$(jq -r '.score' "${found[$k]}")" "$k"; done | sort -n | awk '{print $2}'); do
      f=${found[$c]}; s=$(jq -r '.score' "$f")
      [ "$s" -lt 8 ] || continue
      printf '**[%s. %s — %s/10]**\n' "$c" "$(canonical_name "$c")" "$s"
      jq -r '.weaknesses[] | "- \(.problem)\n  - Failure scenario: \(.failure_scenario)\n  - Severity: \(.severity)"' "$f"
      printf '\n'
    done
  fi
  exit 0
  ;;
*) die "blueprint-merge: unknown command '$cmd' (expected wait|report)." ;;
esac
