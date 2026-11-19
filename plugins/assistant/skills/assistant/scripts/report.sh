#!/usr/bin/env bash
# asst-report — every agent report lands on disk before it is returned. The
# assistant's context gets compacted, and a report held only there is lost with it;
# a row waiting on a lost report waits forever.
#
# Usage: asst-report put    <task-slug> <kind> [--worktree <dir>]
#                           (report on stdin) → prints the path
#        asst-report latest <task-slug> <kind>   → prints the newest path; exit 1 if none
#        asst-report list   <task-slug>
#        asst-report form   <kind>               → prints the form that kind's report fills in
#        asst-report summary                     → per task, its newest report of each kind
# kind: investigation · brief · brief-review · build-<phase> · tests · verify-<review> · advise
# --worktree names the task's checkout when the caller is not in it.
set -uo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$here/root.sh"
op="${1:-}"; slug="${2:-}"; kind="${3:-}"
usage() { sed -n '6,12p' "$0" >&2; exit 2; }
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
if [ "$op" = put ]; then
  shift 3 2>/dev/null
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
# spec_check <kind> <file> — on a project whose config names a spec, a brief or a brief-review
# is filed only once checked against it, or the user is asked what the spec already decides
# (references/brief.md). Checks presence and shape only; prints why it refuses.
needs_you='^[[:space:]]*[-*][[:space:]]+Needs you'
verdict='verdict: spec (decides|silent|ambiguous)'
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
  n=$(rounds brief | tail -1)
  [ -n "$n" ] || { echo "no brief is filed for this task — file it first (asst-report put <slug> brief); the review checks the filed one"; return 1; }
  b="$dir/brief-$n.md"
  bad=$(grep -E 'verdict:' "$2" | grep -vE "$verdict" | head -1)
  [ -z "$bad" ] || { echo "'$bad' — a verdict is 'spec decides', 'spec silent' or 'spec ambiguous'"; return 1; }
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
    # checks against rules it never saw.
    case "$kind" in build-ui|build-integration|build-fix|tests)
      grep -q '^rules: style-pack --paths ' "$f.partial" || {
        rm -f "$f.partial"
        echo "asst-report: NOT FILED — a $kind report needs the line 'rules: style-pack --paths <the files you touched>', naming the run you made before your first edit or test (builder.md, tester.md)" >&2
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
  *) usage ;;
esac
