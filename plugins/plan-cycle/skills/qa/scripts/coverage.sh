#!/usr/bin/env bash
# coverage.sh — did the tests REACH the lines this cycle changed?
#
# WHY THIS EXISTS, AND WHY IT IS NOT A PERCENTAGE
#   `plan-mutation` asks whether a line's effect is asserted. It cannot ask
#   whether the line ran at all: a line no test executes produces no mutant, so
#   it never survives and never appears. The two checks stack — mutation grades
#   what was reached, this grades the reach — and neither substitutes.
#
#   The gate is per LINE, not per percent. A file at 92% and a file at 92% are
#   not the same file: one missed a logging branch, the other missed the error
#   path. `qa/SKILL.md` states the rule this enforces — for each changed file,
#   either every line is executed, or the exception is NAMED WITH ITS REASON —
#   and a percentage cannot express it. So the output is the list of unexecuted
#   lines, and the pass condition is that every one of them carries a reason.
#
# THE ESCAPE HATCH
#   `// coverage-ignore: <reason>` on the line, or on the line directly above
#   it. The reason is mandatory and must be non-empty — an unexplained "not
#   covered" is exactly the gap this exists to stop, and a marker with no reason
#   is that gap wearing a marker. Same shape as `// review-dismiss:`, which the
#   ledger's Gate 4 already scans for.
#
#   `lcov.info` is the source of truth for what ran. Whatever the toolchain
#   already excluded — `// coverage:ignore-file` on generated code, for instance
#   — is simply absent from it and this script never sees those lines.
#
# USAGE
#   plan-coverage [--files a.dart …] -- <test-command…>
#
#   Pass a SCOPED test command, the same scope the change lives in:
#     plan-coverage -- flutter test test/features/trash
#
#   `--coverage` is appended for you if it is not already there. Run this from
#   the repo root — the test command runs in the CALLER's working directory.
#
# EXIT
#   0  every changed file fully executed, or every gap carries a reason
#   1  at least one unexplained unexecuted line, or a changed file no test
#      reached at all
#   2  nothing was measured (no repo, no lcov, the run did not happen)

set -uo pipefail

EXPLICIT_FILES=""
while [ $# -gt 0 ]; do
  case "$1" in
    --files)  shift
              while [ $# -gt 0 ] && [ "$1" != "--" ]; do
                EXPLICIT_FILES="${EXPLICIT_FILES}${1}"$'\n'; shift
              done
              [ "${1:-}" = "--" ] && shift ;;
    --)       shift; break ;;
    -h|--help) sed -n '2,42p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    # A flag this script does not know is never forwarded silently. Measured on
    # mutation.sh's predecessor: an unrecognised flag fell through into the test
    # command, the run widened to the whole suite, and the score looked normal.
    -*)       echo "plan-coverage: unknown flag '$1'. The test command goes after \`--\`." >&2
              echo "  usage: plan-coverage [--files a.dart …] -- <test-command…>" >&2
              exit 2 ;;
    *)        break ;;
  esac
done

[ $# -gt 0 ] || { echo "plan-coverage: need a test command (e.g. plan-coverage -- flutter test test/features/trash)" >&2; exit 2; }

root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "plan-coverage: not in a git repo" >&2; exit 2; }
cd "$root" || exit 2

# --- what to measure --------------------------------------------------------
# Identical scoping to plan-mutation, deliberately: the two gates must grade the
# same file set or "reach then assert" is being claimed over two different
# populations. Generated files are excluded — nobody hand-writes them.
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
[ -n "$files" ] || { echo "plan-coverage: no changed lib/**.dart files — nothing to measure."; exit 0; }
count_files=$(printf '%s\n' "$files" | grep -c .)

# --- run --------------------------------------------------------------------
LCOV=coverage/lcov.info

# A STALE lcov.info IS THE FAILURE THIS GUARDS.
# `flutter test --coverage` leaves the previous run's file in place when it does
# not produce a new one, so a run that tested nothing reports the LAST run's
# reach — full marks over a suite that never executed. Remember the mtime and
# require it to move; do not delete the file, because a run that then fails
# would have destroyed the only evidence of the previous one.
before=0
[ -f "$LCOV" ] && before=$(stat -f %m "$LCOV" 2>/dev/null || stat -c %Y "$LCOV" 2>/dev/null || echo 0)

# `--coverage` is appended rather than required, because the flag belongs to
# this gate and not to the scope the caller is naming. Appending twice is
# harmless but noisy, so only when absent.
set -- "$@"
case " $* " in *" --coverage "*) ;; *) set -- "$@" --coverage ;; esac

echo "plan-coverage: ${count_files} changed file(s); every line must be executed or carry \`// coverage-ignore: <reason>\`."
echo "plan-coverage: running — $*"
started=$(date +%s)
"$@"
test_rc=$?
elapsed=$(( $(date +%s) - started ))

# A RED SUITE CANNOT BE GRADED FOR REACH.
# Same reasoning plan-mutation applies to an aborted engine: a failing test may
# have exited before the lines it was going to execute, so the gaps below would
# be artefacts of the failure rather than findings about the tests.
if [ "$test_rc" -ne 0 ]; then
  echo "plan-coverage: THE SUITE FAILED (exit ${test_rc}) — nothing was measured." >&2
  echo "plan-coverage: reach measured off a red suite is meaningless; a test that fails early never reaches what it was going to cover. Fix the suite first." >&2
  exit 2
fi

after=0
[ -f "$LCOV" ] && after=$(stat -f %m "$LCOV" 2>/dev/null || stat -c %Y "$LCOV" 2>/dev/null || echo 0)
if [ ! -f "$LCOV" ] || [ "$after" -le "$before" ]; then
  cat >&2 <<EOF
plan-coverage: NO COVERAGE WAS WRITTEN. Nothing was measured — this is not full
reach and not a pass of any kind.

  expected: $root/$LCOV  (written by this run)

The suite exited 0 without producing coverage. Usual causes: \`--coverage\` never
reached the runner, or the scope matched no test files at all — both of which
otherwise look exactly like a clean run.
EOF
  exit 2
fi

# --- parse ------------------------------------------------------------------
# One awk pass over lcov: for each SF: record whose path is one of ours, collect
# the DA: lines whose hit count is 0. Paths come back absolute on some
# toolchains and package-relative on others, so strip a leading repo root rather
# than assuming either — without the strip, every record fails to match and the
# gate reports perfect reach over zero files.
uncov=$(awk -v root="$root/" '
  BEGIN { while ((getline f < "/dev/stdin") > 0) want[f] = 1 }
  /^SF:/ {
    p = substr($0, 4); sub("^" root, "", p)
    cur = (p in want) ? p : ""
    if (cur != "") seen[cur] = 1
    next
  }
  cur != "" && /^DA:/ {
    split(substr($0, 4), a, ",")
    if (a[2] + 0 == 0) print cur "\t" a[1]
  }
  END { for (f in seen) print f "\t-" }
' "$LCOV" <<< "$files")

seen_files=$(printf '%s\n' "$uncov" | awk -F'\t' '$2 == "-" { print $1 }' | sort -u)
gaps=$(printf '%s\n' "$uncov" | awk -F'\t' '$2 != "-" && NF == 2' | sort -u -t$'\t' -k1,1 -k2,2n)

# --- classify each gap: reasoned or not -------------------------------------
# The marker is accepted on the line itself or the line directly above it. Above
# is the common shape for a whole statement; on-line suits a trailing branch.
# The reason must be non-empty AFTER the colon — a bare marker is the gap with a
# sticker on it.
explained=""; unexplained=""
while IFS=$'\t' read -r f ln; do
  [ -n "$f" ] || continue
  ctx=$(sed -n "$(( ln > 1 ? ln - 1 : 1 )),${ln}p" "$f" 2>/dev/null)
  reason=$(printf '%s\n' "$ctx" | sed -n 's|.*// *coverage-ignore: *\(.*[^ ]\) *$|\1|p' | tail -1)
  if [ -n "$reason" ]; then
    explained="${explained}${f}:${ln}\t${reason}"$'\n'
  else
    src=$(sed -n "${ln}p" "$f" 2>/dev/null | sed 's/^[[:space:]]*//')
    unexplained="${unexplained}${f}:${ln}\t${src}"$'\n'
  fi
done <<< "$gaps"

# A changed file with NO lcov record at all is not 0% — it is a file no test
# imported. That reads as "nothing to report" in every per-line view, which is
# why it is checked separately and reported first.
unreached=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  printf '%s\n' "$seen_files" | grep -qxF "$f" || unreached="${unreached}${f}"$'\n'
done <<< "$files"

# --- report -----------------------------------------------------------------
n_unreached=$(printf '%s' "$unreached" | grep -c . || true)
n_unexpl=$(printf '%s' "$unexplained" | grep -c . || true)
n_expl=$(printf '%s' "$explained" | grep -c . || true)

echo
printf '%-10s %8s %10s %11s  %s\n' VERDICT 'GAPS' 'REASONED' 'UNEXPLAINED' FILE
while IFS= read -r f; do
  [ -n "$f" ] || continue
  if printf '%s\n' "$unreached" | grep -qxF "$f"; then
    printf '%-10s %8s %10s %11s  %s\n' UNREACHED - - - "$f"
    continue
  fi
  e=$(printf '%s' "$explained"   | grep -c "^${f}:" || true)
  u=$(printf '%s' "$unexplained" | grep -c "^${f}:" || true)
  v=PASS; [ "$u" -gt 0 ] && v=FAIL
  printf '%-10s %8s %10s %11s  %s\n' "$v" "$(( e + u ))" "$e" "$u" "$f"
done <<< "$files"
echo "plan-coverage: elapsed ${elapsed}s."

if [ "$n_unexpl" -gt 0 ]; then
  echo
  echo "Unexecuted, with no reason given:"
  printf '%b' "$unexplained" | while IFS=$'\t' read -r loc src; do
    [ -n "$loc" ] && printf '  • %s  %s\n' "$loc" "$src"
  done
fi

if [ "$n_expl" -gt 0 ]; then
  echo
  echo "Unexecuted, reason given:"
  printf '%b' "$explained" | while IFS=$'\t' read -r loc why; do
    [ -n "$loc" ] && printf '  · %s  — %s\n' "$loc" "$why"
  done
fi

# --- the markdown half, for the PR comment ----------------------------------
# Written every run, pass or fail, because a report that only appears on success
# is a report nobody can use to see what is still open. `plan-qa-report` reads
# this; it is keyed to HEAD so a stale section cannot be posted against a
# different tree.
REPORT="${TMPDIR:-/tmp}/plan-qa-coverage.md"
head_sha=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)
{
  printf '<!-- plan-qa:coverage sha=%s -->\n' "$head_sha"
  printf '### Coverage — reach\n\n'
  printf 'Scope: %s changed file(s), `%s`. Every line executed, or the gap carries a written reason.\n\n' "$count_files" "$*"
  printf '| Verdict | Gaps | Reasoned | Unexplained | File |\n|---|---:|---:|---:|---|\n'
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if printf '%s\n' "$unreached" | grep -qxF "$f"; then
      printf '| **UNREACHED** | – | – | – | `%s` |\n' "$f"; continue
    fi
    e=$(printf '%s' "$explained"   | grep -c "^${f}:" || true)
    u=$(printf '%s' "$unexplained" | grep -c "^${f}:" || true)
    v='PASS'; [ "$u" -gt 0 ] && v='**FAIL**'
    printf '| %s | %s | %s | %s | `%s` |\n' "$v" "$(( e + u ))" "$e" "$u" "$f"
  done <<< "$files"
  if [ "$n_unreached" -gt 0 ]; then
    printf '\n**UNREACHED means no test imported the file at all** — not 0%%%s, but absent from the coverage report entirely.\n' ''
  fi
  if [ "$n_unexpl" -gt 0 ]; then
    printf '\n<details><summary>Unexecuted, no reason given (%s)</summary>\n\n' "$n_unexpl"
    printf '%b' "$unexplained" | while IFS=$'\t' read -r loc src; do
      [ -n "$loc" ] && printf -- '- `%s` — `%s`\n' "$loc" "$src"
    done
    printf '\n</details>\n'
  fi
  if [ "$n_expl" -gt 0 ]; then
    printf '\n<details><summary>Unexecuted, reason given (%s)</summary>\n\n' "$n_expl"
    printf '%b' "$explained" | while IFS=$'\t' read -r loc why; do
      [ -n "$loc" ] && printf -- '- `%s` — %s\n' "$loc" "$why"
    done
    printf '\n</details>\n'
  fi
} > "$REPORT"
echo "plan-coverage: report section — $REPORT"

if [ "$n_unreached" -gt 0 ] || [ "$n_unexpl" -gt 0 ]; then
  cat >&2 <<EOF

plan-coverage: BLOCKED.
$( [ "$n_unreached" -gt 0 ] && printf '\n  %s changed file(s) appear NOWHERE in the coverage report — no test imports them.\n  That is not a low score; it is an unmeasured file, and mutation cannot see it\n  either (an unexecuted line produces no mutant to survive).\n' "$n_unreached" )
$( [ "$n_unexpl" -gt 0 ] && printf '\n  %s unexecuted line(s) with no reason. Either add the test that runs the line,\n  or write why it cannot be run, at the site:\n\n      // coverage-ignore: only a real device enters this branch\n\n  "Not covered" with no reason is the gap this gate exists to stop.\n' "$n_unexpl" )
EOF
  exit 1
fi
exit 0
