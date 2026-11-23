#!/usr/bin/env bash
# asst-report — every agent report lands on disk before it is returned. The
# assistant's context gets compacted, and a report held only there is lost with it;
# a row waiting on a lost report waits forever.
#
# Usage: asst-report put      <slug> <kind> [--worktree <dir>]
#                             (report on stdin) → prints the path
#        asst-report latest   <slug> <kind>   → prints the newest path; exit 1 if none
#        asst-report list     <slug>
#        asst-report form     <kind>          → prints the form that kind's report fills in
#        asst-report summary                  → per task, its newest report of each kind
#        asst-report reviewed <slug> [--worktree <dir>]
#                             → exit 0 when the newest brief has a brief-review filed after
#                               it and the architecture check holds; exit 1 naming what is missing
# kind: investigation · brief · brief-review · build-<phase> · tests · verify-<review> · advise
# --worktree names the task's code worktree when the caller is not in it; reports live in the main checkout's root from every worktree.
set -uo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$here/root.sh"
op="${1:-}"; slug="${2:-}"; kind="${3:-}"
usage() { sed -n '/^# Usage:/,/^# --worktree/p' "$0" >&2; exit 2; }
# One form per report kind, the only copy of its shape; the agents print it here.
if [ "$op" = form ]; then
  k=${slug:-}; case "$k" in build-*) k=build ;; esac
  f="$here/../forms/$k.md"
  [ -n "$k" ] && [ -f "$f" ] || { echo "asst-report: no form for '${slug:-}' — kinds: $(ls "$here/../forms" | sed 's/\.md$//; s/^build$/build-<phase>/' | paste -sd ' ' -)" >&2; exit 2; }
  cat "$f"; exit 0
fi
# Every task's newest report of each kind, in one look: what a scheduler pass reads.
if [ "$op" = summary ]; then
  rd="$(asst_root)/.claude/.assistant/reports"
  for d in "$rd"/*/; do
    [ -d "$d" ] || continue
    s=$(basename "$d")
    line=$(ls "$d" | sed -nE 's/^(.+)-([0-9]+)\.md$/\1 \2/p' | sort -k1,1 -k2,2nr \
      | awk '!seen[$1]++ { printf "%s%s-%s", sep, $1, $2; sep=" · " }')
    echo "$s: ${line:-no reports}"
  done
  exit 0
fi
[ -n "$op" ] && [ -n "$slug" ] || usage
wt=$PWD
if [ "$op" = put ] || [ "$op" = reviewed ]; then
  if [ "$op" = put ]; then shift 3 2>/dev/null; else kind=""; shift 2; fi
  while [ $# -gt 0 ]; do
    case "$1" in
      --worktree) wt="${2:-}"; shift 2 ;;
      *) usage ;;
    esac
  done
  [ -d "$wt" ] || { echo "asst-report: no worktree at $wt" >&2; exit 2; }
fi
root=$(cd "$wt" && asst_root)
dir="$root/.claude/.assistant/reports/$slug"
# Older versions filed these kinds as scout and build-wire: a report under the old
# name is filed under the new one, and `latest` falls back to the old files.
case "$kind" in scout) kind=investigation ;; build-wire) kind=build-integration ;; esac
case "$kind" in investigation) old=scout ;; build-integration) old=build-wire ;; *) old="" ;; esac
# Round numbers of <kind> (default: $kind), ascending — the n in <kind>-<n>.md.
rounds() { ls "$dir" 2>/dev/null | sed -nE "s/^${1:-$kind}-([0-9]+)\.md$/\1/p" | sort -n; }
# newest_brief — sets n to the newest brief's round and b to its path; with none, sets why and fails.
newest_brief() {
  n=$(rounds brief | tail -1); b="$dir/brief-$n.md"
  [ -n "$n" ] || { why="no brief is filed for $slug in $dir — a feature task's design is filed as a brief first (asst-report put $slug brief), then reviewed"; return 1; }
}
# The architecture check (references/verify.md): each condition fires once per task, and only an
# advise report filed after the triggering report with an Architecture check clears it.
cond_a='the 2nd brief version filed after the first build-* report'
cond_b='the first verify-code report after the 2nd build-fix round has a [1.n] fix finding in its Logic block'
# arch_check — fails and sets why when a condition fired and no such advise report follows it.
arch_check() {
  local files=() k r f built=0 briefs=0 fix_rounds=0 in_round=0 b_seen=0 trigger="" cond=""
  for k in brief build-ui build-integration build-fix build-wire verify-code advise; do
    for r in $(rounds "$k"); do files+=("$dir/$k-$r.md"); done
  done
  [ ${#files[@]} -gt 0 ] || return 0
  while IFS= read -r f; do
    k=$(basename "$f" .md); k=${k%-*}
    case "$k" in
      build-*)
        built=1
        if [ "$k" = build-fix ] && [ $in_round = 0 ]; then fix_rounds=$((fix_rounds + 1)); in_round=1; fi ;;
      brief)
        [ $built = 1 ] || continue
        briefs=$((briefs + 1))
        if [ $briefs = 2 ]; then trigger=$f; cond=$cond_a; fi ;;
      verify-code)
        in_round=0
        if [ $fix_rounds = 2 ] && [ $b_seen = 0 ]; then
          b_seen=1
          if awk '/^#/ { on = /^#+[[:space:]]*1[[:space:]]+Logic/; next } on && /^\[1\.[0-9]+\] fix /' "$f" | grep -q .; then
            trigger=$f; cond=$cond_b
          fi
        fi ;;
      advise)
        if awk '/^## Architecture check[[:space:]]*$/ { on = 1; next } on && NF { sub(/[[:space:]]+$/, ""); print; exit }' "$f" \
          | grep -qxE 'Root cause: (not )?architecture'; then trigger=""; fi ;;
    esac
  done < <(ls -tr -- "${files[@]}")
  [ -z "$trigger" ] && return 0
  why="architecture not checked — $trigger: $cond; no advise report filed after it has a '## Architecture check' section whose first line is 'Root cause: architecture' or 'Root cause: not architecture' — dispatch the advisor for an architecture check with that report's path first (references/verify.md)"
  return 1
}
# spec_check <kind> <file> — on a project whose config names a spec, a brief or a brief-review
# is filed only once checked against it, or the user is asked what the spec already decides
# (references/brief.md). Checks presence and shape only; prints why it refuses.
needs_you='^[[:space:]]*[-*][[:space:]]+Needs you'
verdict='verdict: (spec (decides|silent|ambiguous)|case unshown)'
spec_check() {
  local cfg="$root/.claude/assistant.md" spec block bad b n v
  spec=$(asst_field "$cfg" spec)
  [ -n "$spec" ] || { echo "$cfg has no 'spec:' line — ask the user once where the product spec lives (a path, a URL, or none) and write it (references/project.md)"; return 1; }
  [ "$spec" = none ] && return 0
  block=$(awk '/^#+[[:space:]]+Spec pages read[[:space:]]*$/ { on = 1; next } /^#/ { on = 0 } on && NF' "$2")
  [ -n "$block" ] || { echo "a $1 needs a '## Spec pages read' section, one '- <page> · last edited <time>' line per spec page read"; return 1; }
  bad=$(grep -vE '^[-*] .*[^[:space:]].* · last edited [^[:space:]]' <<<"$block" | head -1)
  [ -z "$bad" ] || { echo "under 'Spec pages read', '$bad' is not '- <page> · last edited <time>'"; return 1; }
  if [ "$1" = brief ]; then
    bad=$(grep -E "$needs_you" "$2" | grep -vE 'spec: ("|“|「).+("|”|」) — [^[:space:]]|spec: none in [^[:space:]]' | head -1)
    [ -z "$bad" ] || { echo "'$bad' needs a spec field: 'spec:\"<verbatim quote>\" — <why it doesn't decide this>' or 'spec: none in <the sections checked>'"; return 1; }
    return 0
  fi
  newest_brief || { echo "$why"; return 1; }
  bad=$(grep -E 'verdict:' "$2" | grep -vE "$verdict" | head -1)
  [ -z "$bad" ] || { echo "'$bad' — a verdict is 'spec decides', 'spec decides the result', 'spec decides (combined)', 'case unshown', 'spec silent' or 'spec ambiguous'"; return 1; }
  n=$(grep -cE "$needs_you" "$b"); v=$(grep -cE "$verdict" "$2")
  [ "$n" = "$v" ] || { echo "$v verdict line(s) for the $n 'Needs you' line(s) in $b — one 'verdict:' line per 'Needs you' line, in order"; return 1; }
}

case "$op" in
  put)
    [ -n "$kind" ] || usage
    # A numbered kind files as <kind>-<n>-1.md, which `latest <kind>` never finds.
    [[ $kind =~ -[0-9]+$ ]] && { echo "asst-report: '$kind' carries a round number — pass the bare kind (${kind%-*}); put numbers the rounds itself" >&2; exit 2; }
    mkdir -p "$dir"
    n=$(( $(rounds | tail -1) + 1 ))
    f="$dir/$kind-$n.md"; cat > "$f.partial"
    if [ ! -s "$f.partial" ]; then
      rm -f "$f.partial"; echo "asst-report: empty report on stdin — nothing filed" >&2; exit 1
    fi
    # A builder or tester that never loaded the style pack writes code the verifier then
    # checks against rules it never saw. A builder blocked before its first edit has no file to name.
    case "$kind" in build-ui|build-integration|build-fix|tests)
      grep -qE '^rules: (style-pack --paths |none — blocked before any change$)' "$f.partial" || {
        rm -f "$f.partial"
        echo "asst-report: NOT FILED — a $kind report needs the line 'rules: style-pack --paths <the files you touched>', naming the run you made before your first edit or test (builder.md, tester.md), or 'rules: none — blocked before any change'" >&2
        exit 1
      } ;;
    esac
    case "$kind" in brief|brief-review)
      why=$(spec_check "$kind" "$f.partial") || {
        rm -f "$f.partial"; echo "asst-report: NOT FILED — $why" >&2; exit 1
      } ;;
    esac
    mv -f "$f.partial" "$f"; echo "$f" ;;
  latest)
    [ -n "$kind" ] || usage
    n=$(rounds | tail -1); k=$kind
    [ -n "$n" ] || [ -z "$old" ] || { n=$(rounds "$old" | tail -1); k=$old; }
    [ -n "$n" ] || { echo "asst-report: no $kind report for $slug" >&2; exit 1; }
    echo "$dir/$k-$n.md" ;;
  list) ls "$dir" 2>/dev/null ;;
  # Filing order across kinds is modification time: round numbers order reports only within
  # one kind, and the reports directory is outside git, so no checkout resets it.
  reviewed)
    newest_brief || { echo "asst-report: $why" >&2; exit 1; }
    for m in $(rounds brief-review); do
      [ "$dir/brief-review-$m.md" -nt "$b" ] || continue
      arch_check || { echo "asst-report: $why" >&2; exit 1; }
      echo "brief-$n reviewed by brief-review-$m"; exit 0
    done
    echo "asst-report: brief-$n in $dir has no brief-review filed after it — a verifier reviews this version before a builder implements it (references/brief.md)" >&2
    exit 1 ;;
  *) usage ;;
esac
