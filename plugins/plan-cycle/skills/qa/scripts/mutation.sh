#!/usr/bin/env bash
# mutation.sh — mutation-test the files this cycle actually changed.
#
# WHY THIS EXISTS
#   Line coverage is not test strength: a suite that calls every line and
#   asserts nothing scores 100%. Mutation testing is the check that tells them
#   apart — change the source, re-run the tests, and a mutation nothing turns
#   red on is a hole.
#
# WHY IT IS SCOPED TO THE DIFF
#   Runtime is mutants × (one analyze + one test run), and there is no way
#   around that — each mutant needs its own. Whole-repo is an overnight job, not
#   a gate. The files this cycle touched are both the affordable scope and the
#   one that matters.
#
# THE ENGINE
#   `dart_mutants` (kai-packages), AST-based via package:analyzer. It replaced a
#   regex engine that was blind to exactly the constructs a Flutter `build()` is
#   made of — measured, one construct per file: a ternary, a switch expression
#   and `??` each produced ZERO mutants under the old tool, while `if`,
#   collection-`if`, `&&` and `<=` produced some. A widget file's whole
#   conditional logic could therefore go unmeasured while the score looked fine.
#
#   Two properties of the AST engine matter here and are verified, not assumed:
#   every mutant is compile-checked before it is scored (a mutant that does not
#   compile exits non-zero, which the old engine counted as "detected" — a
#   silently INFLATED score), and a mutant that hangs is killed and scored
#   `timedOut` rather than waited on forever. Neither counts toward total.
#
# USAGE
#   plan-mutation [--min <pct>] [--timeout <s>] [--files a.dart …] -- <test-command…>
#
#   Pass a SCOPED test command — `flutter test test/features/trash`, not a bare
#   `flutter test`. The scope is what makes this affordable.
#
#   ⚠️ The test command runs in the CALLER's working directory. Run this from the
#   repo root. Measured the hard way: invoked from elsewhere it completes, prints
#   a full score, and has tested nothing — the least visible failure there is.
#
# WHILE IT RUNS, THE SOURCE ON DISK IS MUTATED
#   A live mutant compiles and reads as authored code, so anyone else on this
#   worktree — a reviewer, another session, an editor — can read it as the
#   author's. `.mutation-in-progress` at the repo root is the probe: it names the
#   pid, the sha, and the files. Read those paths with `git show <sha>:<path>`
#   while it exists. Exit 3 means the tree was NOT restored.

set -uo pipefail

MIN_SCORE=80        # every changed file must kill this share of its own mutants
MIN_MUTANTS=5       # below this a percentage is arithmetic, not evidence
MUTANT_TIMEOUT=30   # passed through; bounds a single hanging mutant
EXPLICIT_FILES=""

while [ $# -gt 0 ]; do
  case "$1" in
    --min)      MIN_SCORE="${2:-80}"; shift 2 ;;
    --timeout)  MUTANT_TIMEOUT="${2:-30}"; shift 2 ;;
    --files)    shift
                while [ $# -gt 0 ] && [ "$1" != "--" ]; do
                  EXPLICIT_FILES="${EXPLICIT_FILES}${1}"$'\n'; shift
                done
                [ "${1:-}" = "--" ] && shift ;;
    --)         shift; break ;;
    -h|--help)  sed -n '2,36p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    # An unrecognised FLAG is refused, never treated as the start of the test
    # command. Measured: `--yes --budget 60 --files x -- flutter test …` (two
    # flags this script had dropped) fell through the old catch-all, so the
    # WHOLE line — removed flags, `--files`, its argument and all — became the
    # test command, `--files` never parsed, and the run silently widened to the
    # entire 48-file diff. A stale flag has to stop the run, not redefine it.
    -*)         cat >&2 <<EOF
plan-mutation: unknown option "$1".

  --budget / --yes were REMOVED with the regex engine: there is no dry-count
  mode to estimate against, so there is nothing to approve. Each mutant is
  bounded by --timeout instead (default ${MUTANT_TIMEOUT}s).

  usage: plan-mutation [--min <pct>] [--timeout <s>] [--files a.dart …] -- <test-command…>
EOF
                exit 2 ;;
    *)          break ;;
  esac
done

[ $# -gt 0 ] || { echo "plan-mutation: need a test command (e.g. plan-mutation -- flutter test test/features/trash)" >&2; exit 2; }
TEST_CMD="$*"
command -v jq >/dev/null 2>&1 || { echo "plan-mutation: jq is required" >&2; exit 2; }

root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "plan-mutation: not in a git repo" >&2; exit 2; }
cd "$root" || exit 2

# --- IS SOMEONE ALREADY MUTATING THIS TREE? ---------------------------------
# For the length of a run the working tree holds a live mutant: it compiles, it
# carries no marker, and it reads as authored code. Measured as a near-miss — a
# reviewer on this same worktree read one line twice minutes apart, got two
# different relational operators, and almost filed "your rationale contradicts
# your own code" off a mutant. Nothing in that chain lied. The marker written
# below is what makes the state probe-able by everyone who is NOT the process
# doing the measuring, which is where the whole hazard lives.
MARKER="$root/.mutation-in-progress"
if [ -f "$MARKER" ]; then
  mpid=$(sed -n 's/^pid:[[:space:]]*//p' "$MARKER" | head -1)
  if [ -n "$mpid" ] && kill -0 "$mpid" 2>/dev/null; then
    cat >&2 <<EOF
plan-mutation: another run (pid $mpid) is mutating this tree right now. Two runs
sharing one working tree overwrite each other's mutants, so BOTH scores measure
the other run rather than the tests. Wait for it, or use a separate worktree.
EOF
    exit 2
  fi
  cat >&2 <<EOF
plan-mutation: REFUSING TO START. A previous run left $MARKER behind and the
process it names is gone, so it was killed before it could restore. The files it
lists may still hold a live mutant — and starting now would snapshot that mutant
AS IF IT WERE YOUR SOURCE, then faithfully restore it at the end and make it
permanent.

$(cat "$MARKER")

Diff those paths, put back anything that is not yours, then remove the marker:
  rm $MARKER
EOF
  exit 2
fi

# --- a retired engine's report must not sit at the path people read ---------
# Until 0.28.x this script wrote its findings to `mutation-report.md`. The AST
# switch dropped the writer and printed to stdout instead — and left every
# already-written file in place, at the canonical path, with a plausible mtime
# and a clean `git status`. Measured: three survived across the two consumer
# projects, and a reviewer read one and nearly filed three verbatim-identical
# survivor lists from the regex engine's answers. Nothing overwrites these,
# because nothing writes them any more; they are only ever removed by hand.
for stale in build/mutation-report.md mutation-report.md; do
  [ -f "$stale" ] || continue
  cat >&2 <<EOF
plan-mutation: REFUSING TO START — $stale is output from the RETIRED regex
engine (nothing has written that path since 0.29.0, so it cannot be current).
Its mutant set and its scores are not comparable to this engine's, and it reads
as a normal report.

  rm $stale

This script prints its findings to stdout and writes no report file.
EOF
  exit 2
done

# --- the engine has to be here before anything else happens -----------------
# Switching from the regex engine to the AST one changed an UNDECLARED
# prerequisite: `mutation_test` was `dart pub global activate`d, `dart_mutants`
# is a dev_dependency of the project. Without this check the first sign is
# `Could not find package dart_mutants` buried under a run that has already
# printed a file count and a threshold, which reads like the tool worked and
# found nothing.
if ! grep -q '^  dart_mutants:' pubspec.yaml 2>/dev/null; then
  cat >&2 <<'EOF'
plan-mutation: this project does not depend on `dart_mutants`, so there is no
engine to run. Nothing was measured.

Add it to pubspec.yaml under dev_dependencies:

  dev_dependencies:
    dart_mutants:
      git:
        url: https://github.com/kai-tw/kai-packages.git
        path: packages/dart_mutants
        ref: dart_mutants-v0.1.0

then `flutter pub get`. (It replaced `mutation_test`, which was installed
globally — the prerequisite moved from the machine to the project.)
EOF
  exit 2
fi

# --- what to mutate --------------------------------------------------------
# Generated files are excluded: nobody hand-writes them, so a surviving mutant
# there is a finding about a generator, not about the tests.
if [ -n "$EXPLICIT_FILES" ]; then
  files=$(printf '%s' "$EXPLICIT_FILES" | grep -v '^$')
else
  base=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
  base=${base#origin/}
  [ -n "$base" ] || base=main
  git rev-parse --verify --quiet "$base" >/dev/null 2>&1 || base=main
  files=$( { git diff --name-only "$base"...HEAD 2>/dev/null
             git diff --name-only HEAD 2>/dev/null; } \
           | sort -u \
           | grep -E '^lib/.*\.dart$' \
           | grep -vE '\.(g|freezed|config|gen)\.dart$|^lib/generated/' )
fi
files=$(printf '%s\n' "$files" | grep -v '^$' | while IFS= read -r f; do [ -f "$f" ] && printf '%s\n' "$f"; done)
[ -n "$files" ] || { echo "plan-mutation: no changed lib/**.dart files to mutate — nothing to do."; exit 0; }
count_files=$(printf '%s\n' "$files" | grep -c .)

out=$(mktemp -d) || exit 2
snap=$(mktemp -d) || exit 2

# MUTATED SOURCE MUST NEVER OUTLIVE THE RUN.
#
# The engine restores on SIGINT/SIGTERM, which its authors verified against a
# real binary. This snapshot is the second belt: a run killed by SIGKILL, an OOM,
# or a crash has no chance to clean up, and whichever mutant was live is then
# sitting in the working tree. Measured on the predecessor: a harness timeout
# left an argument-swap mutation in NovelGlide's `http_client_repository_impl`.
# That one did not compile, which is luck — most mutants do, and a valid-looking
# one is exactly the edit that gets committed.
restore_sources() {
  [ -d "$snap" ] || return 0
  ( cd "$snap" 2>/dev/null && find . -type f -print ) 2>/dev/null | sed 's|^\./||' \
    | while IFS= read -r rel; do
        [ -n "$rel" ] || continue
        cmp -s "$snap/$rel" "$rel" 2>/dev/null && continue
        cp "$snap/$rel" "$rel" 2>/dev/null \
          && echo "plan-mutation: restored mutated source $rel" >&2
      done
}

# Restoring is not the same as having restored. A restore that silently failed
# prints a score, exits 0, and leaves an edit that compiles and looks authored —
# the same failure-shaped-like-success this gate exists to remove. Prove it
# against the SNAPSHOT: that is the only correct baseline, because the pre-run
# tree legitimately differs from HEAD (you are mutating files you just changed),
# so comparing against a commit would flag your own work as a residue.
verify_restored() {
  [ -d "$snap" ] || return 0
  bad=$( ( cd "$snap" 2>/dev/null && find . -type f -print ) 2>/dev/null | sed 's|^\./||' \
         | while IFS= read -r rel; do
             [ -n "$rel" ] || continue
             cmp -s "$snap/$rel" "$rel" 2>/dev/null || printf '%s\n' "$rel"
           done )
  [ -n "$bad" ] || return 0
  cat >&2 <<EOF

plan-mutation: RESTORE FAILED — the working tree still differs from the snapshot
taken before this run. These files may hold a live mutant:

$(printf '%s\n' "$bad" | sed 's/^/  /')

Your pre-run copies are KEPT at:
  $snap

Compare each against that copy before you commit anything. Delete the directory
yourself once the tree is right.
EOF
  return 1
}

# The exit status has to carry this. A run that scored PASS but left a mutant
# behind is not a pass: the tree is contaminated, and a caller reading the exit
# code would take exit 0 plus a score as a clean result — the failure shape this
# whole script exists to remove. On that path the snapshot is deliberately NOT
# deleted, because it is the only remaining copy of the pre-run source.
cleanup() {
  rc=$?
  trap - EXIT INT TERM
  restore_sources
  if verify_restored; then
    rm -rf "$snap"
  else
    rc=3
  fi
  rm -f "$MARKER" "$MARKER.tmp"
  rm -rf "$out"
  exit "$rc"
}
trap cleanup EXIT INT TERM

printf '%s\n' "$files" | while IFS= read -r f; do
  [ -n "$f" ] || continue
  mkdir -p "$snap/$(dirname "$f")" && cp "$f" "$snap/$f"
done

head_sha=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)
# Written to a sibling and moved into place, because `cat > "$MARKER"` creates
# the file before it writes it: a poller that samples in that window sees a
# zero-byte marker with no pid line. `mv` within one directory is atomic, so the
# marker is never observable half-written. (Reading it empty fails safe — the
# guard above refuses on a missing pid — but "refuses for the wrong reason" is
# not the same as correct.)
cat > "$MARKER.tmp" <<EOF
plan-mutation IN PROGRESS — the files below are being mutated RIGHT NOW.

pid:      $$
head:     $head_sha
snapshot: $snap

$(printf '%s\n' "$files" | sed 's/^/  /')

Source read from the working tree may be a MUTANT: it compiles, carries no
marker, and looks like the author wrote it. While this file exists, read those
paths with \`git show $head_sha:<path>\` rather than from disk. Uncommitted work
in them was copied to the snapshot directory above before the run started.

This marker is removed when the run ends. If it is still here and no process
holds the pid above, the run was killed and the tree may still hold a mutant.
EOF
mv -f "$MARKER.tmp" "$MARKER"

# --- run --------------------------------------------------------------------
# No pre-run estimate: the engine has no dry-count mode, so an "N mutants × M
# seconds" figure would be invented rather than measured. What bounds the run
# instead is --mutant-timeout per mutant plus the diff-sized scope. Elapsed time
# is reported at the end so the next caller can size the scope from real data.
echo "plan-mutation: ${count_files} changed file(s), threshold ${MIN_SCORE}% per file, ${MUTANT_TIMEOUT}s per mutant."
echo "plan-mutation: no up-front estimate is possible (the engine has no dry-count mode) — watch the elapsed line below."
echo "plan-mutation: WHILE THIS RUNS the source on disk may be a live mutant. Read those files with \`git show ${head_sha}:<path>\`, not from the working tree — anyone sharing this worktree included. Marker: .mutation-in-progress"
started=$(date +%s)
# shellcheck disable=SC2086
dart run dart_mutants --test-command "$TEST_CMD" --mutant-timeout "$MUTANT_TIMEOUT" --json $files > "$out/report.json" 2>"$out/err"
elapsed=$(( $(date +%s) - started ))

jq -e . "$out/report.json" >/dev/null 2>&1 || {
  # Say what happened, not what was declined. "Not scoring anything off that"
  # reads like a cautious judgement about a result; there IS no result — the
  # engine did not produce one, so nothing was measured at all. A message that
  # sounds careful over a run that never happened is the failure shape this
  # whole gate exists to remove.
  cat >&2 <<EOF
plan-mutation: THE ENGINE DID NOT RUN. Nothing was measured — this is not a low
score, not a pass, and not a result of any kind. Its output was:

$(head -20 "$out/err" 2>/dev/null | sed 's/^/  /')

Until that is fixed, no file in this diff has a mutation score.
EOF
  exit 2
}

abort=$(jq -r '.abortReason // empty' "$out/report.json")
if [ -n "$abort" ]; then
  echo "plan-mutation: ABORTED — ${abort}" >&2
  echo "plan-mutation: a mutation score off a red suite is meaningless (every mutant looks detected). Fix the suite first." >&2
  exit 1
fi

# --- score, per file --------------------------------------------------------
# Per-file, not aggregate: an aggregate lets a well-tested file carry a badly
# tested one. Measured on NovelGlide's http_client — 100% and 67% averaged to
# 68%, which names neither.
#
# `total` already excludes invalid and timedOut, so the percentage is over
# mutants that actually ran. Both counts are still REPORTED, because a file whose
# candidates were mostly rejected has a tiny effective sample and its score is
# arithmetic rather than evidence — the same emptiness as a low mutant count.
#
# Paths come back absolute; the table is relative, so normalise or every row
# fails to match the file it is about.
rows=$(jq -r --arg root "$root/" --argjson min "$MIN_SCORE" --argjson floor "$MIN_MUTANTS" '
  .files | to_entries[] | .value as $v
  | ($v.filePath | sub("^" + $root; "")) as $rel
  | (if $v.total > 0 then (($v.detected * 100) / $v.total | floor) else -1 end) as $score
  | [ $rel,
      (if $score < 0 then "-" else ($score|tostring) end),
      ($v.total|tostring), ($v.invalid|tostring), ($v.timedOut|tostring),
      (if $score < 0 then "NO-MUTANTS"
       elif $score < $min then (if $v.total < $floor then "FAIL LOW-SIGNAL" else "FAIL" end)
       elif $v.total < $floor then "PASS LOW-SIGNAL"
       else "PASS" end) ]
  | @tsv' "$out/report.json")

echo
printf '%-18s %5s %8s %8s %9s  %s\n' VERDICT SCORE MUTANTS INVALID TIMEDOUT FILE
printf '%s\n' "$rows" | awk -F'\t' '{ s = ($2 == "-") ? "  n/a" : sprintf("%4s%%", $2);
  printf "%-18s %5s %8s %8s %9s  %s\n", $6, s, $3, $4, $5, $1 }'
echo "plan-mutation: elapsed ${elapsed}s."

surv=$(jq -r '.files | to_entries[] | .value.undetectedMutants[]?
  | "  • \(.filePath | split("/") | last):\(.line):\(.column)  \(.operatorName) — \(.description)"' "$out/report.json")
[ -n "$surv" ] && { echo; echo "Surviving mutants:"; printf '%s\n' "$surv"; }

# Survivors grouped by operator, because the pool asks TWO different questions
# and each takes a different fix. A `statement_deletion` survivor means nothing
# asserts the line ran at all — the test never looks at its effect. Every other
# operator survives because a choice is unpinned: the branch, the boundary, the
# fallback. Adding an assertion fixes the first; adding a case fixes the second,
# and doing the wrong one leaves the mutant alive.
#
# Counts, never a per-operator score: the report gives `detected` as a file
# total with no operator attached, so the denominator per operator does not
# exist. A percentage here would be invented. An unknown operator name still
# prints — a new one added upstream must not silently vanish from this summary.
byop=$(jq -r '[.files[].undetectedMutants[]?.operatorName] | group_by(.)
  | map({n: length, op: .[0]}) | sort_by(-.n)[] | "\(.n)\t\(.op)"' "$out/report.json" 2>/dev/null)
[ -n "$byop" ] && {
  echo
  echo "Survivors by operator:"
  printf '%s\n' "$byop" | awk -F'\t' '
    BEGIN {
      q["statement_deletion"]              = "nothing asserts these lines ran"
      q["condition_negation"]              = "the guard true/false choice is unpinned"
      q["relational_operator_replacement"] = "the boundary is unpinned"
      q["logical_operator_replacement"]    = "which operand decides is unpinned"
      q["arithmetic_operator_replacement"] = "the arithmetic result is unasserted"
      q["ternary_swap"]                    = "the branch is unpinned"
      q["switch_expression_arm_swap"]      = "the arm mapping is unpinned"
      q["null_coalescing_deletion"]        = "the fallback is unpinned"
    }
    { printf "  %3s  %-34s %s\n", $1, $2, ($2 in q) ? q[$2] : "(unrecognised operator)" }'
}

if printf '%s\n' "$rows" | awk -F'\t' '$6 ~ /NO-MUTANTS|LOW-SIGNAL/' | grep -q .; then
  cat >&2 <<EOF

plan-mutation: NOTE — a score needs mutants to be a measurement, and some files
above have almost none. Read those rows as "not measured", never as "verified".
A high INVALID count means most candidates were rejected by the compile gate, so
what remains is a small and possibly unrepresentative sample of that file.
EOF
fi

if printf '%s\n' "$rows" | awk -F'\t' '$6 ~ /^FAIL/' | grep -q .; then
  cat >&2 <<EOF

plan-mutation: BLOCKED — a changed file scored under ${MIN_SCORE}%. Each survivor
above is either a missing case or an assertion that does not actually assert;
line coverage cannot see either. Add the case that kills it.

If a survivor is genuinely equivalent (the mutant cannot change behaviour), say
so at the site — equivalent mutants are unkillable by definition, which is why
the threshold is not 100%, and a survivor with no written reason is
indistinguishable from a hole.
EOF
  exit 1
fi
exit 0
