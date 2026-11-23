#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# One project with `spec: none` and a git worktree of it; check.sh files briefs and
# brief-reviews per slug in a set order, stamps each file one minute after the last (round
# numbers order reports only within a kind), then runs the review check and prints
# `<case>=<exit code>` and each output line as `<case>: <line>`. A second project, `tr`, has
# its config committed, so its worktree `trtree` holds a config of its own.
set -euo pipefail
git init -q wt
mkdir -p wt/.claude
printf 'spec: none\n' > wt/.claude/assistant.md
git -C wt -c user.name=e -c user.email=e@e commit -q --allow-empty -m init
git -C wt worktree add -q ../tree
git init -q tr
mkdir -p tr/.claude
printf 'spec: none\n' > tr/.claude/assistant.md
git -C tr add .claude/assistant.md
git -C tr -c user.name=e -c user.email=e@e commit -q -m init
git -C tr worktree add -q ../trtree
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
# Config committed: the brief filed from the worktree as references/brief.md says, the
# brief-review from the main checkout without a flag, as verifier.md does.
tfile() { # tfile <dir> <slug> <kind> <file> [--worktree <dir>] — sets $tdir to the directory it landed in
  local d=$1 s=$2 k=$3 f=$4 p; shift 4; tdir=""
  p=$(cd "$d" && asst-report put "$s" "$k" "$@" < "$ws/$f") || { echo "tracked file $s $k failed"; return; }
  m=$((m + 1)); touch -t "2026112011$(printf %02d "$m")" "$p"
  tdir=$(cd "$(dirname "$p")" && pwd -P)
}
tfile "$ws/trtree" tracked brief brief.md --worktree "$ws/trtree"; bdir=$tdir
tfile "$ws/tr" tracked brief-review review.md; rdir=$tdir
[ -n "$bdir" ] && [ "$bdir" = "$rdir" ] && echo "tracked-same-dir=1" || echo "tracked-same-dir=0 brief:$bdir review:$rdir"
run tracked-main  "$ws/tr"     tracked
run tracked-tree  "$ws/trtree" tracked
run tracked-flag  "$ws/tr"     tracked --worktree "$ws/trtree"
# A refusal names the directory it read: the one the unreviewed brief landed in.
tfile "$ws/trtree" tracked-unrev brief brief.md --worktree "$ws/trtree"
run tracked-unrev "$ws/trtree" tracked-unrev
names=0
for d in "$tdir" "${tdir#/private}"; do [ -n "$d" ] && grep -qF -- "$d" "$ws/out" && names=1; done
echo "tracked-unrev-names-dir=$names"
SH
