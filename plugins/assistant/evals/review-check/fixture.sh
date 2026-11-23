#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# One project with `spec: none` and a git worktree of it; check.sh files briefs and
# brief-reviews per slug in a set order, stamps each file one minute after the last (round
# numbers order reports only within a kind), then runs the review check and prints
# `<case>=<exit code>` and each output line as `<case>: <line>`.
set -euo pipefail
git init -q wt
mkdir -p wt/.claude
printf 'spec: none\n' > wt/.claude/assistant.md
git -C wt -c user.name=e -c user.email=e@e commit -q --allow-empty -m init
git -C wt worktree add -q ../tree
printf '# Export — Decision brief            demo · feature · 2026-11-20\n- Decided  Stream the file · Reason: size\n' > brief.md
printf '## 1 Logic\npassed: 1 2 5\n' > review.md

cat > check.sh <<'SH'
ws=$PWD; m=0
sub=reviewed
if asst-report 2>&1 | grep -qE 'asst-report[[:space:]]+reviewed[[:space:]]+<slug>'; then echo "usage=1"; else echo "usage=0"; fi
file() { # file <slug> <kind…> — files each kind in order, one minute apart
  local s=$1 k f; shift
  for k in "$@"; do
    [ "$k" = brief ] && f=brief.md || f=review.md
    p=$(cd "$ws/wt" && asst-report put "$s" "$k" < "$ws/$f") || { echo "file $s $k failed"; continue; }
    m=$((m + 1)); touch -t "2026112010$(printf %02d "$m")" "$p"
  done
}
run() { # run <case> <dir> <slug> [--worktree <dir>]
  local c=$1 d=$2 s=$3; shift 3
  ( cd "$d" && asst-report "$sub" "$s" "$@" ) >"$ws/out" 2>&1
  echo "$c=$?"; sed "s/^/$c: /" "$ws/out"
}
file reviewed   brief brief-review
file unreviewed brief
file stale      brief brief-review brief
file again      brief brief-review brief brief-review
file late       brief brief brief-review
# No brief at all: another report and a free-form design file only.
file nobrief    notes
printf 'design\n' > "$(dirname "$(cd "$ws/wt" && asst-report latest nobrief notes)")/design.md"
run reviewed       "$ws/wt"   reviewed
run unreviewed     "$ws/wt"   unreviewed
run stale          "$ws/wt"   stale
run again          "$ws/wt"   again
run late           "$ws/wt"   late
run nobrief        "$ws/wt"   nobrief
run tree-reviewed  "$ws/tree" reviewed
run tree-stale     "$ws/tree" stale
run flag-reviewed  "$ws"      reviewed --worktree "$ws/wt"
run flag-stale     "$ws"      stale    --worktree "$ws/wt"
# A build report filed before any change has no paths to give style-pack.
( cd "$ws/wt" && printf 'blocked: brief not reviewed\nrules: none — blocked before any change\n' \
  | asst-report put rulesnone build-integration ) >"$ws/out" 2>&1
echo "rules-none=$?"; sed "s/^/rules-none: /" "$ws/out"
SH
