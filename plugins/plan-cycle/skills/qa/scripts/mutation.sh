#!/usr/bin/env bash
# mutation.sh — mutation-test the files this cycle actually changed.
#
# WHY THIS EXISTS
#   Line coverage is not test strength: a suite that calls every line and
#   asserts nothing scores 100%. Mutation testing is the check that tells them
#   apart — flip an operator in the source, re-run the tests, and a mutation
#   nothing turns red on is a hole. Measured on an 8-line function with six
#   tests written to be complete, it surfaced four survivors: two planted weak
#   assertions AND two real gaps the author had not noticed (`<= 0` → `== 0`
#   with no negative case, `&&` → `||` with the one distinguishing combination
#   untested).
#
# WHY IT IS SCOPED TO THE DIFF
#   Runtime is mutations × one test run, and there is no way around that — each
#   mutant needs its own run. On NovelGlide a narrowly scoped `flutter test
#   <dir>` is ~9s, so a single file with 50 mutants is ~7.5 minutes. Whole-repo
#   is not a gate, it is an overnight job. The files this cycle touched are both
#   the affordable scope and the one that matters.
#
# WHY IT ESTIMATES BEFORE IT RUNS
#   The failure mode of this tool is starting a six-hour run by accident. `--dry`
#   counts mutants without testing, and one timed run gives the per-mutant cost,
#   so the estimate is measured rather than guessed. Over the budget it stops and
#   shows the arithmetic; `--yes` proceeds anyway.
#
# USAGE
#   plan-mutation [--yes] [--budget <minutes>] <test-command…>
#   plan-mutation [--yes] --files a.dart b.dart -- <test-command…>
#
#   Pass a SCOPED test command — `flutter test test/features/trash`, not a bare
#   `flutter test`. The scope is what makes this affordable, and the estimate
#   will tell you if you got it wrong.

set -uo pipefail

BUDGET_MIN=20
ASSUME_YES=""
EXPLICIT_FILES=""
# Every changed file must kill at least this share of its own mutants. Per-file,
# not aggregate: an aggregate lets a well-tested file carry a badly-tested one.
MIN_SCORE=80
# Below this many mutants a percentage is arithmetic, not evidence — 0/0 and 2/2
# both read as 100%. Flagged, not failed.
MIN_MUTANTS=5

while [ $# -gt 0 ]; do
  case "$1" in
    --yes|-y)   ASSUME_YES=1; shift ;;
    --budget)   BUDGET_MIN="${2:-20}"; shift 2 ;;
    --min)      MIN_SCORE="${2:-80}"; shift 2 ;;
    --files)    shift
                while [ $# -gt 0 ] && [ "$1" != "--" ]; do
                  EXPLICIT_FILES="${EXPLICIT_FILES}${1}"$'\n'; shift
                done
                [ "${1:-}" = "--" ] && shift ;;
    --)         shift; break ;;
    -h|--help)  sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)          break ;;
  esac
done

[ $# -gt 0 ] || { echo "plan-mutation: need a test command (e.g. plan-mutation flutter test test/features/trash)" >&2; exit 2; }
TEST_CMD="$*"

# The tool is `dart pub global activate`d, which does not put itself on PATH.
command -v mutation_test >/dev/null 2>&1 || PATH="$PATH:$HOME/.pub-cache/bin"
command -v mutation_test >/dev/null 2>&1 || {
  cat >&2 <<'EOF'
plan-mutation: mutation_test is not installed. Install it with:

  dart pub global activate mutation_test

(It is a Dart tool, so no Python and no system pollution — house-rules §Tooling.)
EOF
  exit 2
}

root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "plan-mutation: not in a git repo" >&2; exit 2; }
cd "$root" || exit 2

# --- what to mutate --------------------------------------------------------
# Committed-on-branch plus uncommitted, against the base. Generated files are
# excluded: nobody hand-writes them, so a surviving mutant there is a finding
# about a generator, not about the tests.
if [ -n "$EXPLICIT_FILES" ]; then
  files=$(printf '%s' "$EXPLICIT_FILES" | grep -v '^$')
else
  base=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
  base=${base:-origin/main}
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

cfg=$(mktemp -t planmut).xml || exit 2
out=$(mktemp -d) || exit 2
snap=$(mktemp -d) || exit 2

# MUTATED SOURCE MUST NEVER OUTLIVE THE RUN.
#
# mutation_test edits the real files in place and restores them as it goes, so a
# run that is INTERRUPTED — Ctrl-C, a harness timeout, a crash — leaves whichever
# mutant was live sitting in the working tree. Measured: a 2-minute timeout on
# NovelGlide left an argument-swap mutation in
# `http_client_repository_impl.dart`. That one did not compile, which is luck —
# most mutants do, and a surviving-by-accident mutant is exactly the kind of
# valid-looking edit that gets committed.
#
# So snapshot every target first and restore unconditionally on exit. When the
# tool cleaned up after itself the copy is identical and this is a no-op.
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
trap 'restore_sources; rm -f "$cfg" "${cfg%.xml}.one.xml"; rm -rf "$out" "$snap"' EXIT INT TERM

{
  printf '<?xml version="1.0" encoding="UTF-8"?>\n<mutations version="1.0">\n  <files>\n'
  printf '%s\n' "$files" | while IFS= read -r f; do printf '    <file>%s</file>\n' "$f"; done
  printf '  </files>\n  <commands>\n'
  printf '    <command group="test" expected-return="0" working-directory="." timeout="600">%s</command>\n' "$TEST_CMD"
  printf '  </commands>\n  <threshold failure="80">\n'
  printf '    <rating over="95" name="A"/>\n    <rating over="80" name="B"/>\n'
  printf '    <rating over="60" name="C"/>\n    <rating over="0" name="F"/>\n'
  printf '  </threshold>\n</mutations>\n'
} > "$cfg"

# Take the snapshot BEFORE anything can mutate them.
printf '%s\n' "$files" | while IFS= read -r f; do
  [ -n "$f" ] || continue
  mkdir -p "$snap/$(dirname "$f")" && cp "$f" "$snap/$f"
done

# --- the suite must be green first -----------------------------------------
# Mutation scores off a red suite are meaningless: every mutant reads as
# "detected" because the command was already failing.
echo "plan-mutation: ${count_files} changed file(s); checking the suite is green first…"
start=$(date +%s)
if ! eval "$TEST_CMD" >/dev/null 2>&1; then
  echo "plan-mutation: ABORTED — \`${TEST_CMD}\` is not green. A mutation score off a red suite is meaningless (every mutant looks detected). Fix the suite first." >&2
  exit 1
fi
per=$(( $(date +%s) - start ))
[ "$per" -lt 1 ] && per=1

# --- estimate ---------------------------------------------------------------
# No `-q` here: quiet suppresses the "Found N mutations" line this parses, and
# the count then reads as 0, which prints "nothing to do" over a real backlog.
muts=$(mutation_test -d -f none -o "$out" "$cfg" 2>/dev/null | grep -oE 'Found [0-9]+ mutations' | grep -oE '[0-9]+' | head -1)
case "$muts" in ''|*[!0-9]*) muts=0 ;; esac
[ "$muts" -gt 0 ] || { echo "plan-mutation: 0 mutations found in those files (no mutable operators) — nothing to do."; exit 0; }

# Compared in SECONDS, not whole minutes: integer minutes truncate, so a 20m50s
# estimate reads as 20 and slips past a 20-minute budget.
est_s=$(( muts * per ))
budget_s=$(( BUDGET_MIN * 60 ))
echo "plan-mutation: ${muts} mutation(s) × ${per}s per test run ≈ ${est_s}s ($(( est_s / 60 ))m$(( est_s % 60 ))s)."
if [ "$est_s" -gt "$budget_s" ] && [ -z "$ASSUME_YES" ]; then
  cat >&2 <<EOF

plan-mutation: STOPPED — the estimate is over the ${BUDGET_MIN} min budget.

Runtime is mutations × one test run and there is no way around it — each mutant
needs its own run. Narrow the test command (\`flutter test test/features/<one>\`,
not a bare \`flutter test\`), narrow the files with --files, or accept the cost
with --yes / --budget <minutes>.
EOF
  exit 2
fi

# --- the real run, PER FILE -------------------------------------------------
# One run per file, not one run over all of them, because the gate is per-file:
# an aggregate score lets a well-tested file carry a bad one. Measured on
# NovelGlide's http_client — 100% on `uri_https_guard.dart` and 67% on
# `http_client_repository_impl.dart` aggregated to 68%, which names neither.
# The per-file cost is identical (the same mutants either way); only process
# startup repeats. A single-file run's own summary IS that file's score, so
# nothing has to parse a per-file breakdown out of a console format.
#
# --exclude-strings because the mutations are regex text replacements, not AST
# edits: without it an operator inside a string literal gets mutated and the
# survivor is an artefact of the tool, not a hole in the tests.
echo "plan-mutation: running (threshold ${MIN_SCORE}% per file)…"
rc=0
rows=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  one="${cfg%.xml}.one.xml"
  {
    printf '<?xml version="1.0" encoding="UTF-8"?>\n<mutations version="1.0">\n  <files>\n'
    printf '    <file>%s</file>\n' "$f"
    printf '  </files>\n  <commands>\n'
    printf '    <command group="test" expected-return="0" working-directory="." timeout="600">%s</command>\n' "$TEST_CMD"
    printf '  </commands>\n  <threshold failure="%s">\n    <rating over="0" name="-"/>\n  </threshold>\n</mutations>\n' "$MIN_SCORE"
  } > "$one"
  # `tr '\r' '\n'` first: the progress bar rewrites one line with carriage
  # returns, so without it the summary lines are unreachable to grep.
  outp=$(mutation_test --exclude-strings -f md -o "$out" "$one" 2>&1 | tr '\r' '\n')
  tot=$(printf '%s\n' "$outp" | grep -oE 'Found [0-9]+ mutations' | grep -oE '[0-9]+' | head -1)
  und=$(printf '%s\n' "$outp" | grep -oE 'Undetected Mutations: [0-9]+' | grep -oE '[0-9]+' | head -1)
  case "$tot" in ''|*[!0-9]*) tot=0 ;; esac
  case "$und" in ''|*[!0-9]*) und=0 ;; esac
  if [ "$tot" -eq 0 ]; then
    rows="${rows}${f}	-	0	NO-MUTANTS
"
    continue
  fi
  score=$(( (tot - und) * 100 / tot ))
  verdict="PASS"
  [ "$score" -lt "$MIN_SCORE" ] && { verdict="FAIL"; rc=1; }
  # A percentage over a handful of mutants is not a measurement. Flagged rather
  # than failed — see the LOW-SIGNAL note printed below.
  [ "$tot" -lt "$MIN_MUTANTS" ] && verdict="${verdict} LOW-SIGNAL"
  rows="${rows}${f}	${score}	${tot}	${verdict}
"
done <<EOF
$files
EOF

echo
printf '%s' "$rows" | awk -F'\t' '{ s = ($2 == "-") ? "  n/a" : sprintf("%3s%%", $2);
  printf "  %-16s %s  %4s mutant(s)  %s\n", $4, s, $3, $1 }'
echo

if printf '%s' "$rows" | awk -F'\t' '$4 ~ /NO-MUTANTS|LOW-SIGNAL/' | grep -q .; then
  cat >&2 <<EOF
plan-mutation: NOTE — a score needs mutants to be a measurement, and some files
here have almost none. That is usually code STYLE, not test quality: the builtin
rules negate only a braced \`if (…) {\`, and a bare \`<\` / \`>\` is not a mutation
source at all (mutating it would corrupt Dart generics). Measured on identical
clamp logic: brace-less with \`<\`/\`>\` → 0 mutants; braced → 2; braced with
\`<=\`/\`>=\` → 6. So a file written that way can score 100% with no tests at all.
Read those rows as "not measured", never as "verified".
EOF
fi

# Land the report under build/ when that is gitignored — writing it to the repo
# root leaves an untracked file behind, which is the exact thing this plugin's
# own dirty-tree and unpushed-work gates exist to stop.
report=$(find "$out" -name '*.md' 2>/dev/null | head -1)
if [ -n "$report" ]; then
  if git check-ignore -q build 2>/dev/null; then
    mkdir -p build && keep="build/mutation-report.md"
  else
    keep="mutation-report.md"
  fi
  cp "$report" "$keep" 2>/dev/null && echo "plan-mutation: surviving mutations written to ./${keep}"
fi

if [ "$rc" -ne 0 ]; then
  cat >&2 <<EOF

plan-mutation: BLOCKED — a changed file scored under ${MIN_SCORE}%. Those lines can
be changed and NO test notices. Each survivor is either a missing case or an
assertion that does not actually assert. Line coverage cannot see either.

Add the case that kills it. If a survivor is genuinely equivalent (the mutant
behaves identically), say so in the test file at the site — a survivor with no
written reason is indistinguishable from a hole.
EOF
fi
exit "$rc"
