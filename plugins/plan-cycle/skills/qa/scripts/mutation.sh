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
    # The removal note is shown ONLY for the flags actually removed. Printed
    # unconditionally it explains the wrong thing: a caller who typed
    # `--test-command` (the ENGINE's flag, never this script's) read the removal
    # text, concluded plan-mutation had dropped a flag it never had, and was
    # about to file a migration note for a change that never happened. Right
    # refusal, wrong reason attached to it.
    -*)         case "$1" in
                  --budget|--yes)
                    why='
  --budget / --yes were REMOVED with the regex engine: there is no dry-count
  mode to estimate against, so there is nothing to approve. Each mutant is
  bounded by --timeout instead.' ;;
                  --test-command)
                    why='
  --test-command belongs to the ENGINE, not to this script, and never was a
  plan-mutation flag. Put the test command after `--` and it is forwarded.' ;;
                  *) why='' ;;
                esac
                cat >&2 <<EOF
plan-mutation: unknown option "$1".
${why}

  usage: plan-mutation [--min <pct>] [--timeout <s>] [--files a.dart …] -- <test-command…>
         --timeout defaults to ${MUTANT_TIMEOUT}s per mutant.
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

This script prints its findings to stdout and writes nothing into the repo. The
engine's raw JSON is kept outside it, at the path the run prints on the way out.
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
# THE ENGINE'S RESOLVED VERSION, NOT ITS DECLARATION.
#
# `pubspec.yaml` says what was asked for; `pubspec.lock` says what pub actually
# resolved. Reading the lock separates three states a yaml grep collapses into
# one, and the third is the one that bites silently:
#   - no yaml entry          → never declared
#   - yaml but no lock entry → declared, `pub get` never run
#   - lock entry below the floor → an engine that runs, scores and reports
#                              normally while measuring or costing the wrong
#                              thing; see the two cases the gate distinguishes
#
# Not `dart run dart_mutants --version`, which is what this comment used to
# propose: that flag does not exist (measured — the engine answers "Could not
# find an option named --version" and exits 64). The lockfile is also free,
# where spawning dart costs a few hundred ms on every run.
#
# The floor is 0.2.3, not 0.2.0, because of what a timeout costs on a machine
# somebody is also working on. `flutter test` is three processes; through 0.2.2
# the timeout SIGKILLed only the direct child, and POSIX reparents the orphaned
# `flutter_tester` to init rather than killing it, so it went on running the
# mutant with nothing left to reap it — measured by the engine at 1.86 GB on
# the kill and 2.25 GB three seconds later, roughly 130 MB/s indefinitely, per
# timed-out mutant, SURVIVING the run that created it. Two runs exhausted a
# workstation. `trap cleanup` below cannot help: the escaped process is no
# longer a descendant of anything this script can see. And the remedy this gate
# prints for a timeout is a LARGER --timeout, which multiplies the exposure,
# because a mutant allocates for the whole window.
MIN_ENGINE=0.2.3

# A older than B. Used by the gate and again by its explanation, which differs
# by how far back the resolved version is.
older_than() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" != "$2" ]; }

lock_ver=""
[ -f pubspec.lock ] && lock_ver=$(awk '
  /^  dart_mutants:/ { inpkg=1; next }
  inpkg && /^  [a-zA-Z]/ { inpkg=0 }
  inpkg && /^    version:/ { gsub(/[" ]/,""); sub(/^version:/,""); print; exit }
' pubspec.lock)

if [ -n "$lock_ver" ] && older_than "$lock_ver" "$MIN_ENGINE"; then
  # Two different defects live below the floor, and naming the wrong one sends
  # the reader after the wrong thing. Branch on which it actually is.
  if older_than "$lock_ver" 0.2.0; then
    why="$lock_ver ships FOUR operators — ternary, switch-arm, ?? and relational. It runs,
scores and prints a normal-looking table over half the mutation space: statement
deletion, condition negation, &&/|| and arithmetic produce nothing, and no row
says which engine produced the number."
  else
    why="$lock_ver measures correctly and LEAKS a runaway process on every timeout. It
SIGKILLs the direct child; the \`flutter_tester\` underneath is orphaned to init
instead of killed, and goes on running the mutant at roughly 130 MB/s until the
machine is out of memory. It outlives this run, so the cost accumulates across
runs — and the remedy this gate prints for a timeout, a larger --timeout, makes
each leak bigger."
  fi
  cat >&2 <<EOF
plan-mutation: this project resolves dart_mutants $lock_ver, and this gate needs
$MIN_ENGINE or newer. Nothing was measured.

$why

Update the ref in pubspec.yaml to dart_mutants-v$MIN_ENGINE or newer, then
\`flutter pub get\`.
EOF
  exit 2
fi

if [ -z "$lock_ver" ] && grep -q '^  dart_mutants:' pubspec.yaml 2>/dev/null; then
  cat >&2 <<'EOF'
plan-mutation: pubspec.yaml declares `dart_mutants` but pubspec.lock does not
resolve it, so the engine is not installed. Nothing was measured.

  flutter pub get

(Declared is not installed — this is the state a yaml-only check called ready.)
EOF
  exit 2
fi

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
        ref: dart_mutants-v0.2.3

then `flutter pub get`. (It replaced `mutation_test`, which was installed
globally — the prerequisite moved from the machine to the project.)

Take the ref above verbatim; both halves of it are load-bearing. v0.1.0 ships
four operators and v0.2.0 eight, and the four it adds — statement deletion,
condition negation, `&&`/`||`, arithmetic — are the half that asks whether a
line's effect is asserted at all; pinned below v0.2.0 the tool runs, scores and
reports normally over a pool that cannot see any of that, and nothing about the
output says which engine produced it. v0.2.3 is where a timed-out mutant stops
orphaning a test process that outlives the run and eats the machine.
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

# THE ENGINE'S RAW REPORT OUTLIVES THE RUN.
#
# `$out` is deleted on every exit path, and the report lived only in it — so
# "just jq the report yourself" was false for everyone, this script's own author
# included. Choosing not to DISPLAY one of the engine's fields is this layer's
# call; destroying its output so nobody else can read it is not, and the two got
# conflated. It matters because every table below RE-DERIVES the display with
# jq: a field the engine adds and this script does not read is invisible and
# unreachable at once, which is how `timedOutMutants` went unread across four
# consecutive reports on one PR.
#
# A stable path, not `$out`'s random name — an unpredictable path is barely
# better than a deleted one when the reader is a hand-back three messages later.
# One file, overwritten per run: this is the last run's evidence, not an archive.
# Outside the repo, because `build/mutation-report.md` above is the standing
# lesson about what a stale report at a canonical in-repo path does to a reader.
REPORT_KEEP="${TMPDIR:-/tmp}/plan-mutation-report.json"

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

# Preserved BEFORE the parse check, not after: a report this script cannot read
# is exactly the one somebody needs the bytes of, and the check below exits.
[ -s "$out/report.json" ] && cp "$out/report.json" "$REPORT_KEEP" 2>/dev/null

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

Whatever it wrote on stdout is at $REPORT_KEEP.

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

# EVERY FILE WE ASKED ABOUT HAS TO APPEAR IN THE REPORT.
#
# `jq -e` above proves the report is parseable JSON, not that it contains
# anything. A report of `{"files":{}}` passes that check, produces no rows, and
# every read below treats no-rows as nothing-to-block — an empty table and
# exit 0 over a run that measured nothing. Same shape as the leg-2 gate that was
# printing "suite green" off an unparsed report: emptiness only means "clean"
# once the thing that fills it is known to have run.
#
# The assertion is per file rather than a count, so a partial report — the engine
# skipping one path it could not handle — names which file lost its score instead
# of silently shrinking the scope of the gate.
missing=$(printf '%s\n' "$files" | while IFS= read -r f; do
  [ -n "$f" ] || continue
  jq -e --arg root "$root/" --arg f "$f" \
    'any(.files[]?; (.filePath | sub("^" + $root; "")) == $f)' "$out/report.json" >/dev/null 2>&1 \
    || printf '%s\n' "$f"
done)
if [ -n "$missing" ]; then
  cat >&2 <<EOF

plan-mutation: THE REPORT IS MISSING FILES IT WAS ASKED TO MEASURE. These have
no score — not a low one, none at all:

$(printf '%s\n' "$missing" | sed 's/^/  /')

The engine returned a parseable report that does not cover them, so no verdict
below applies to these files. This is not a pass.
EOF
  exit 2
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
# The engine echoes back the paths it was given, which are relative here, but it
# has returned absolute ones — so strip a leading repo root rather than assuming
# either. Without the strip, an absolute path makes every row fail to match the
# file it is about.
rows=$(jq -r --arg root "$root/" --argjson min "$MIN_SCORE" --argjson floor "$MIN_MUTANTS" '
  .files | to_entries[] | .value as $v
  | ($v.filePath | sub("^" + $root; "")) as $rel
  | (if $v.total > 0 then (($v.detected * 100) / $v.total | floor) else -1 end) as $score
  # A timeout is not a slow kill and not a survivor — it is a candidate that was
  # never answered, exactly like an `invalid` one. `total` already excludes it,
  # so the SCORE is honest; what was not honest is the row, which read as a
  # finished measurement. Measured in CherishCRM: 6 scored against 16 timed out
  # printed as a plain `FAIL 0%`, with 16 of 22 candidates silently unasked.
  # The flag is not a ratio but the only question that matters: COULD the
  # unmeasured candidates change this verdict? Score them both ways — every
  # timeout a survivor, then every timeout a kill. If the threshold sits between
  # those two, the verdict is undetermined and the row must not read as an
  # answer. If it sits outside them, the verdict holds no matter what those
  # mutants would have done, and the row is honest.
  #
  # This invents no constant, and it catches what a ratio misses. Measured on
  # the CherishCRM file `google_session.dart`: 4 detected of 5, one timed out.
  # Only
  # 17% unmeasured and the pool clears the floor, so both a ratio test and the
  # mutant floor wave it through as a plain `PASS 80%` — but 4/6 and 5/6 are
  # 66% and 83%, straddling the threshold. That pass rested entirely on a
  # mutant nobody ran.
  | ($v.total + $v.timedOut) as $cand
  | (if $cand > 0 then (($v.detected * 100) / $cand | floor) else 0 end) as $worst
  | (if $cand > 0 then ((($v.detected + $v.timedOut) * 100) / $cand | floor) else 0 end) as $best
  | ($v.timedOut > 0 and $worst < $min and $best >= $min) as $undetermined
  | ($v.total < $floor or $undetermined) as $thin
  | [ $rel,
      (if $score < 0 then "-" else ($score|tostring) end),
      ($v.total|tostring), ($v.invalid|tostring), ($v.timedOut|tostring),
      (if $score < 0 then "NO-MUTANTS"
       elif $score < $min then (if $thin then "FAIL LOW-SIGNAL" else "FAIL" end)
       elif $thin then "PASS LOW-SIGNAL"
       else "PASS" end) ]
  | @tsv' "$out/report.json")

echo
printf '%-18s %5s %8s %8s %9s  %s\n' VERDICT SCORE MUTANTS INVALID TIMEDOUT FILE
printf '%s\n' "$rows" | awk -F'\t' '{ s = ($2 == "-") ? "  n/a" : sprintf("%4s%%", $2);
  printf "%-18s %5s %8s %8s %9s  %s\n", $6, s, $3, $4, $5, $1 }'
echo "plan-mutation: elapsed ${elapsed}s."
echo "plan-mutation: raw engine report — $REPORT_KEEP (every field, including any this table does not render)."

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

# Timeouts get their own note, because the remedy is different from a thin
# mutant pool and the two causes behind them are indistinguishable from here.
#
# The IDENTITIES, not just the count. A LOW-SIGNAL row now blocks the turn, so a
# timeout stops the caller and then has to tell them what to go and look at —
# "re-run with a larger --timeout" without naming which mutants leaves them
# re-running the whole file to find out. The engine has carried these since
# 0.2.1 and this script read only the count, which is the same shape of miss as
# the deleted report above: the display is re-derived here, so a field nobody
# adds a jq for does not exist for anyone downstream.
if printf '%s\n' "$rows" | awk -F'\t' '$5 > 0' | grep -q .; then
  to_total=$(printf '%s\n' "$rows" | awk -F'\t' '{ n += $5 } END { print n+0 }')
  timed=$(jq -r '.files | to_entries[] | .value.timedOutMutants[]?
    | "  • \(.filePath | split("/") | last):\(.line):\(.column)  \(.operatorName) — \(.description)"' "$out/report.json" 2>/dev/null)
  cat >&2 <<EOF

plan-mutation: ${to_total} mutant(s) TIMED OUT — those candidates were never
answered. They are not kills and not survivors, so they are excluded from the
score, and the rows above under-report how much of each file was actually asked.
$( [ -n "$timed" ] && printf '\nTimed-out mutants:\n%s' "$timed" )

A timeout has two causes and this tool cannot tell them apart:
  · the budget is too tight — ${MUTANT_TIMEOUT}s must cover a FULL run of your test
    command, so a command that already takes most of that leaves no headroom;
  · the mutant genuinely hangs the code, which is a real finding.

Re-run those files with a larger --timeout. If the timeouts disappear it was the
budget; if one persists, that mutant is hanging and worth reading.

Raising --timeout raises PEAK MEMORY too — a mutant that allocates inside its
loop allocates for the whole window — so widen it on the files that timed out,
not on the whole diff.
EOF
fi

if printf '%s\n' "$rows" | awk -F'\t' '$6 ~ /NO-MUTANTS|LOW-SIGNAL/' | grep -q .; then
  cat >&2 <<EOF

plan-mutation: NOTE — a score needs mutants to be a measurement, and some files
above have almost none. Read those rows as "not measured", never as "verified".
A high INVALID count means most candidates were rejected by the compile gate, so
what remains is a small and possibly unrepresentative sample of that file.
EOF
fi

# --- the markdown half, for the PR comment ----------------------------------
# Written every run, pass or fail, because a report that only appears on success
# is one nobody can use to see what is still open. `plan-qa-report` reads this
# and its coverage sibling; the sha in the marker is what stops a section from
# an earlier tree being posted against this one.
REPORT="${TMPDIR:-/tmp}/plan-qa-mutation.md"
head_short=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)
{
  printf '<!-- plan-qa:mutation sha=%s -->\n' "$head_short"
  printf '### Mutation — is the effect asserted?\n\n'
  printf 'Threshold %s%%%s per file, %ss per mutant, %s changed file(s). A LOW-SIGNAL row was **not measured**, whatever percentage it shows.\n\n' \
    "$MIN_SCORE" '' "$MUTANT_TIMEOUT" "$count_files"
  printf '| Verdict | Score | Mutants | Invalid | Timed out | File |\n|---|---:|---:|---:|---:|---|\n'
  printf '%s\n' "$rows" | awk -F'\t' 'NF>=6 {
    s = ($2 == "-") ? "–" : $2 "%"
    v = ($6 ~ /^FAIL|LOW-SIGNAL/) ? "**" $6 "**" : $6
    printf "| %s | %s | %s | %s | %s | `%s` |\n", v, s, $3, $4, $5, $1 }'
  if [ -n "$surv" ]; then
    printf '\n<details><summary>Surviving mutants</summary>\n\n'
    printf '%s\n' "$surv" | sed 's|^  • |- `|; s|  \([a-z_]*\) — |` — `\1` — |'
    printf '\n</details>\n'
  fi
  if [ -n "${timed:-}" ]; then
    printf '\n<details><summary>Timed-out mutants — never answered, excluded from the score</summary>\n\n'
    printf '%s\n' "$timed" | sed 's|^  • |- `|; s|  \([a-z_]*\) — |` — `\1` — |'
    printf '\n</details>\n'
  fi
} > "$REPORT"
# The raw-report path goes to STDOUT, never into $REPORT. `plan-qa-report` posts
# $REPORT verbatim as a PR comment, and a local TMPDIR path is a pointer to
# nothing for everyone who reads it there — wrong machine, and cleared on reboot
# even on this one. Same reason `archivist/references/notion-kb.md §No repo
# pointers` keeps navigation out of the KB: the artefact has to stand alone.
echo "plan-mutation: report section — $REPORT"
echo "plan-mutation: raw engine report — $REPORT_KEEP"

# LOW-SIGNAL BLOCKS. It always meant "not measured", and qa/SKILL.md always said
# such a row is not a pass — but the script exited 0 on it, so the discipline
# lived only in prose. Measured twice on CherishCRM: `google_sign_in_button.dart`
# printed PASS LOW-SIGNAL 100% off ONE mutant with two timed out, and was 33%
# once all three ran; `google_session.dart` printed PASS 80% and was 66%. Both
# rows were labelled correctly and shipped anyway. No improvement to the label
# reaches that — only the exit code does.
#
# NO-MUTANTS is deliberately NOT here: nothing to mutate is the expected result
# for a declarative file, and blocking it would push logic INTO widgets to make
# something measurable.
if printf '%s\n' "$rows" | awk -F'\t' '$6 ~ /^FAIL|LOW-SIGNAL/' | grep -q .; then
  cat >&2 <<EOF

plan-mutation: BLOCKED.
$( printf '%s\n' "$rows" | awk -F'\t' '$6 ~ /^FAIL/' | grep -q . && cat <<'UNDER'

  Scored under the threshold. Each survivor above is either a missing case or an
  assertion that does not actually assert; line coverage cannot see either. Add
  the case that kills it.
UNDER
)$( printf '%s\n' "$rows" | awk -F'\t' '$6 ~ /LOW-SIGNAL/' | grep -q . && cat <<'THIN'

  A LOW-SIGNAL row was NOT measured, whatever percentage it shows — a 100% over
  two mutants is arithmetic, not evidence, and it blocks for that reason rather
  than for its score. Two ways in, with different remedies:
    · timeouts left the verdict undetermined → re-run those files with a larger
      --timeout; if it resolves, the score was never the problem
    · the mutant pool is genuinely thin → the file cannot be graded this way.
      Say so in the hand-back, with what you checked instead.
THIN
)
$( [ "$(jq -r '[.files[]?.detected] | add // 0' "$out/report.json" 2>/dev/null)" = "0" ] && cat <<'ZERO'

NOTE — not one mutant was detected, anywhere. Two things look identical here: a
suite that asserts nothing, and a test command that ran no tests at all. Confirm
the command actually executes tests over these files before treating the list
above as a list of missing cases.
ZERO
)

If a survivor is genuinely equivalent (the mutant cannot change behaviour), say
so at the site — equivalent mutants are unkillable by definition, which is why
the threshold is not 100%, and a survivor with no written reason is
indistinguishable from a hole.
EOF
  exit 1
fi
exit 0
