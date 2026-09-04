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
#   not a finding), and `severity` must be `blocking` when score < 6. A
#   weakness may add `directions`: an array of >=2 non-empty strings — never
#   1, which reads as a recommendation instead of divergent angles.
#
# THE VERIFICATION ROUND (--prev <prior round's dir>)
#   A re-review verifies the prior round; it is not a fresh judgment — a
#   dimension re-derived from scratch always finds something new to say about
#   a 6–7, which is how a plan grows new findings every fix instead of
#   converging. So with --prev every prior weakness has an id (`<criterion>.<n>`,
#   positional — `prior` prints them) and every file must account for each:
#     {"criterion": 7, "dimension": "error-handling", "score": 7,
#      "cites": [...],
#      "resolved": ["7.1"],
#      "weaknesses": [
#        {"id": "7.2", "origin": "prior", "problem": "…", "failure_scenario": "…", "severity": "weakness"},
#        {"origin": "diff-introduced", "problem": "…", "failure_scenario": "…", "severity": "weakness"},
#        {"origin": "newly-observed", "missed_because": "round 1 never read §Data flow row 4",
#         "problem": "…", "failure_scenario": "…", "severity": "weakness"}],
#      "observations": ["non-scored note — a judgment call the diff did not touch"]}
#   `origin` is required on every weakness: `prior` (still open; `id` must be a
#   prior id), `diff-introduced` (the fix broke it), `newly-observed` (neither —
#   then `missed_because` must name what the prior round failed to read; without
#   it the item is an `observations` entry, not a weakness, and does not score).
#   A prior id that is neither in `resolved` nor carried as `origin: prior` is
#   INVALID — a weakness cannot vanish without a disposition.
#   A dimension the diff did not touch is carried: copy the prior file and add
#   `"carried": true` (score must equal the prior score; no origin checks).
#
# Usage:
#   blueprint_merge.sh wait   <dir> --criteria 1,5,6,7 [--timeout 480] [--prev <dir>]
#   blueprint_merge.sh report <dir> --criteria 1,5,6,7 [--prev <dir>]
#   blueprint_merge.sh prior  <prev-dir> --criteria 1,5,6,7     # ids for the child briefs
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
[ -n "$cmd" ] && [ -n "$dir" ] || die "Usage: blueprint_merge.sh {wait|report|prior} <dir> --criteria <csv> [--timeout <sec>] [--prev <dir>]"
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
# prior round: pscore[c]=score, pids[c]="c.1 c.2 …" (positional ids), pfile[c]=file
# ---------------------------------------------------------------------------
pscore=(); pids=(); pfile=()
load_prior() {
  local f c s n i ids
  [ -d "$prev" ] || die "blueprint-merge: --prev '$prev' is not a directory."
  for f in "$prev"/*.json; do
    [ -e "$f" ] || continue
    jq -e . "$f" >/dev/null 2>&1 || continue
    c=$(jq -r '.criterion // empty' "$f"); s=$(jq -r '.score // empty' "$f")
    case "$c$s" in ''|*[!0-9]*) continue ;; esac
    pscore[$c]="$s"; pfile[$c]="$f"
    n=$(jq -r '.weaknesses | length' "$f" 2>/dev/null || echo 0)
    ids=""; i=1
    while [ "$i" -le "$n" ]; do ids="$ids $c.$i"; i=$((i + 1)); done
    pids[$c]="${ids# }"
  done
}
[ -n "$prev" ] && load_prior

has_id() {  # has_id <id> <space-separated list>
  case " $2 " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

is_carried() { [ "$(jq -r '.carried // false' "$1")" = "true" ]; }

# Verification-round checks (only with --prev). Prints the reason; empty = ok.
verify_against_prior() {
  local f=$1 crit=$2 score=$3 ids id
  ids=${pids[$crit]-}
  if is_carried "$f"; then
    [ -n "${pscore[$crit]-}" ] || { printf 'carried, but the prior round has no criterion %s' "$crit"; return; }
    [ "$score" = "${pscore[$crit]}" ] || printf 'carried, but score %s differs from the prior %s — a carried dimension is the prior file verbatim' "$score" "${pscore[$crit]}"
    return
  fi
  if [ "$(jq -r '[.weaknesses[]? | select((.origin // "") | IN("prior","diff-introduced","newly-observed") | not)] | length' "$f")" -gt 0 ]; then
    printf 'a weakness has no .origin (prior | diff-introduced | newly-observed) — a verification round says where each one came from'; return
  fi
  for id in $(jq -r '.weaknesses[]? | select(.origin == "prior") | .id // "(none)"' "$f"); do
    has_id "$id" "$ids" || { printf 'origin:prior weakness cites id %s, which is not a prior id for criterion %s (%s)' "$id" "$crit" "${ids:-none}"; return; }
  done
  for id in $(jq -r '.resolved[]? // empty' "$f"); do
    has_id "$id" "$ids" || { printf '.resolved cites id %s, which is not a prior id for criterion %s (%s)' "$id" "$crit" "${ids:-none}"; return; }
    [ "$(jq -r --arg id "$id" '[.weaknesses[]? | select(.origin == "prior" and .id == $id)] | length' "$f")" -eq 0 ] \
      || { printf 'prior id %s is both resolved and still open' "$id"; return; }
  done
  for id in $ids; do
    [ "$(jq -r --arg id "$id" '([.resolved[]? | select(. == $id)] + [.weaknesses[]? | select(.origin == "prior" and .id == $id)]) | length' "$f")" -gt 0 ] \
      || { printf 'prior weakness %s is neither in .resolved nor carried as origin:prior — a weakness cannot vanish without a disposition' "$id"; return; }
  done
  if [ "$(jq -r '[.weaknesses[]? | select(.origin == "newly-observed" and ((.missed_because // "") == ""))] | length' "$f")" -gt 0 ]; then
    printf 'a newly-observed weakness has no .missed_because (what the prior round failed to read) — without it the item is an .observations entry, not a weakness'; return
  fi
}

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
      elif [ "$(jq -r '[.weaknesses[] | select(((.directions // []) | length) > 0) | select(([.directions[] | select(. != "")] | length) < 2)] | length' "$f")" -gt 0 ]; then
        reason="a weakness has .directions with fewer than 2 non-empty entries — divergent means >=2, or omit the field"
      fi
    fi
    [ -z "$reason" ] && [ -n "$prev" ] && reason=$(verify_against_prior "$f" "$crit" "$score")

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

  total=0; sub8=0; sub6=0; regressed=""
  n_res=0; n_open=0; n_diff=0; n_new=0; newdims=""
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
      if is_carried "$f"; then delta=" $p carried |"
      elif [ -z "$p" ]; then delta=' — |'
      elif [ "$p" -ge 8 ] && [ "$s" -lt 8 ]; then
        delta=" **$p → $s REGRESSION** |"; regressed="$regressed $c:$(canonical_slug "$c")"
      elif [ "$s" -lt "$p" ]; then delta=" $p → $s ↓ |"
      elif [ "$s" -gt "$p" ]; then delta=" $p → $s ↑ |"
      else delta=" $p → $s = |"; fi
      if ! is_carried "$f"; then
        n_res=$((n_res + $(jq -r '.resolved // [] | length' "$f")))
        n_open=$((n_open + $(jq -r '[.weaknesses[]? | select(.origin == "prior")] | length' "$f")))
        n_diff=$((n_diff + $(jq -r '[.weaknesses[]? | select(.origin == "diff-introduced")] | length' "$f")))
        k=$(jq -r '[.weaknesses[]? | select(.origin == "newly-observed")] | length' "$f")
        n_new=$((n_new + k)); [ "$k" -gt 0 ] && newdims="$newdims $c:$(canonical_slug "$c")"
      fi
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
  if [ -n "$prev" ]; then
    printf 'CONVERGENCE: prior weaknesses resolved %d · still open %d · diff-introduced %d · newly-observed %d\n' "$n_res" "$n_open" "$n_diff" "$n_new"
    [ -n "$newdims" ] && printf 'NEWLY-OBSERVED in%s — not in the prior round and not caused by the diff. Each carries\nits missed_because; the caller routes these to the user by kind, never into another round.\n' "$newdims"
  fi
  printf '\n'

  if [ "$sub8" -gt 0 ]; then
    printf '## Weaknesses (ascending score — every one blocks `approve`)\n\n'
    for c in $(for k in "${want[@]}"; do printf '%s %s\n' "$(jq -r '.score' "${found[$k]}")" "$k"; done | sort -n | awk '{print $2}'); do
      f=${found[$c]}; s=$(jq -r '.score' "$f")
      [ "$s" -lt 8 ] || continue
      printf '**[%s. %s — %s/10]**\n' "$c" "$(canonical_name "$c")" "$s"
      if [ -n "$prev" ] && ! is_carried "$f"; then
        jq -r --arg c "$c" '.weaknesses | to_entries[] | .value as $w |
          "- [\($c).\(.key + 1)] \(if $w.origin == "prior" then "still open (was \($w.id))" else $w.origin end): \($w.problem)\n  - Failure scenario: \($w.failure_scenario)\n  - Severity: \($w.severity)"
          + (if $w.origin == "newly-observed" then "\n  - Missed because: \($w.missed_because)" else "" end)
          + (if ($w.directions // []) != [] then "\n  - Directions (unranked, not a recommendation): " + ($w.directions | join(" · ")) else "" end)' "$f"
      else
        jq -r --arg c "$c" '.weaknesses | to_entries[] | "- [\($c).\(.key + 1)] \(.value.problem)\n  - Failure scenario: \(.value.failure_scenario)\n  - Severity: \(.value.severity)"
          + (if (.value.directions // []) != [] then "\n  - Directions (unranked, not a recommendation): " + (.value.directions | join(" · ")) else "" end)' "$f"
      fi
      printf '\n'
    done
  fi
  exit 0
  ;;

prior)
  # <dir> is the prior round's dir here: emit each in-scope criterion's weaknesses with their ids.
  prev=$dir; pscore=(); pids=(); pfile=(); load_prior
  for c in $(printf '%s\n' "${want[@]}" | sort -n); do
    f=${pfile[$c]-}
    if [ -z "$f" ]; then
      printf '{"criterion": %s, "dimension": "%s", "prior": "none — first pass for this dimension"}\n' "$c" "$(canonical_slug "$c")"
      continue
    fi
    jq -c --arg c "$c" '{criterion: .criterion, dimension: .dimension, score: .score,
      weaknesses: [.weaknesses | to_entries[] | {id: "\($c).\(.key + 1)", problem: .value.problem, failure_scenario: .value.failure_scenario, severity: .value.severity}]}' "$f"
  done
  exit 0
  ;;
*) die "blueprint-merge: unknown command '$cmd' (expected wait|report|prior)." ;;
esac
