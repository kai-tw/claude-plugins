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
#   path. The rule this enforces — for each changed file, either every line is
#   executed, or the exception is NAMED WITH ITS REASON — is one a percentage
#   cannot express. So the output is the list of unexecuted
#   lines, and the pass condition is that there are none.
#
# THERE IS NO ESCAPE HATCH
#   An earlier version accepted `// coverage-ignore: <reason>` on or above an
#   unexecuted line. It was retired because it was abused: the reason became
#   the thing written instead of the test. An unexecuted changed line is now
#   either tested or reported — the report is the honest record, not a marker.
#
#   The toolchain's own pragmas are closed for the same reason. `flutter test`
#   drops lines under `// coverage:ignore-line` / `-start` … `-end` / `-file`
#   from `lcov.info` before this script reads it, so an unexecuted line under
#   one looks exactly like an executed one. Any changed file that carries such
#   a pragma — or a leftover `// coverage-ignore:` marker, which now exempts
#   nothing and only claims to — blocks until it is removed. Generated files
#   are excluded by name below and never reach that check.
#
# LINES THE VM NEVER RECORDS
#   A statement with no call or allocation in it — `throw const E();`,
#   `throw 'msg';`, `throw kError;` — gets no `DA:` line at all, so an error
#   path no test entered reads like a line with no code. Branch coverage closes
#   that for statements: every block (if/else body, switch case, catch) gets a
#   `BRDA:` record, and one at 0 is a gap, reported on the line the block opens.
#   An expression arm — `x ?? (throw …)`, `c ? throw … : v` — gets no record
#   of its own under either, whatever it throws, so it blocks as UNMEASURABLE
#   until it is a statement (`if (x == null) throw …;`) the gate can see.
#
# USAGE
#   plan-coverage [--files a.dart …] -- <test-command…>
#
#   Pass a SCOPED test command, the same scope the change lives in:
#     plan-coverage -- flutter test test/features/trash
#
#   `--coverage --branch-coverage` is appended for you where absent. Run this
#   from the repo root — the test command runs in the CALLER's working directory.
#
# EXIT
#   0  every changed line executed
#   1  at least one unexecuted line or branch, a changed file no test reached at
#      all, a changed file carrying a coverage pragma, or an unmeasurable throw
#   2  nothing was measured (no repo, no base ref, no lcov, the run did not
#      happen)
#
#   Scope is taken against `origin/<default branch>` when that ref exists, and
#   the base used is printed in the report header. The LOCAL branch of the same
#   name is the fallback, not the default: it only moves when someone pulls it.

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
    -h|--help) sed -n '2,59p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
base=
if [ -n "$EXPLICIT_FILES" ]; then
  files=$(printf '%s' "$EXPLICIT_FILES" | grep -v '^$')
else
  # Prefer the REMOTE-tracking ref. `origin/<branch>` is what the PR merges
  # into and `git fetch` keeps it current without touching the working tree;
  # the LOCAL branch of the same name only moves when someone checks it out and
  # pulls, which a squash-merge workflow never does. A stale local base drags
  # the three-dot merge-base backwards, so every PR merged since lands in
  # scope and the gate grades files this branch never opened — loudly, by name,
  # with line counts. The base actually used is printed in the report header,
  # so the next wrong one is visible instead of inferred.
  base=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
  base=${base#origin/}
  [ -n "$base" ] || base=main
  tried="origin/$base $base origin/main main"
  resolved=
  for cand in $tried; do
    git rev-parse --verify --quiet "$cand" >/dev/null 2>&1 && { resolved=$cand; break; }
  done
  # No base means no scope. Diffing an unresolvable ref yields an empty file
  # list, which reads downstream as "nothing changed" and exits 0 — a gate that
  # could not run, wearing the face of one that passed.
  [ -n "$resolved" ] || {
    echo "plan-coverage: no base ref resolves (tried: $(printf %s\\n $tried | awk '!s[$0]++' | paste -sd' ' -)) — pass --files to say what to measure." >&2
    exit 2
  }
  base=$resolved
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
case " $* " in *" --branch-coverage "*) ;; *) set -- "$@" --branch-coverage ;; esac

echo "plan-coverage: ${count_files} changed file(s); every line must be executed — no exemptions."
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
# One awk pass over lcov: for each SF: record whose path is one of ours, print
# every DA: and BRDA: record as "<file>\t<line>\t<line|branch|hit>" — a DA at 0
# is an unexecuted line, a BRDA at 0 (or `-`) a block never entered. Paths come
# back absolute on some toolchains and package-relative on others, so strip a
# leading repo root rather than assuming either — without the strip, every
# record fails to match and the gate reports perfect reach over zero files.
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
    print cur "\t" a[1] "\t" (a[2] + 0 == 0 ? "line" : "hit")
  }
  cur != "" && /^BRDA:/ {
    split(substr($0, 6), a, ",")
    print cur "\t" a[1] "\t" (a[4] == "-" || a[4] + 0 == 0 ? "branch" : "hit")
  }
  END { for (f in seen) print f "\t-" }
' "$LCOV" <<< "$files")

seen_files=$(printf '%s\n' "$uncov" | awk -F'\t' '$2 == "-" { print $1 }' | sort -u)
# One gap per line; a DA at 0 outranks a BRDA opening on the same line.
gaps=$(printf '%s\n' "$uncov" | awk -F'\t' '$3 == "line" || $3 == "branch"' \
       | sort -t$'\t' -k1,1 -k2,2n -k3,3r | awk -F'\t' '!s[$1 FS $2]++')

# --- gaps and pragmas -------------------------------------------------------
unexecuted=""
while IFS=$'\t' read -r f ln kind; do
  [ -n "$f" ] || continue
  src=$(sed -n "${ln}p" "$f" 2>/dev/null | sed 's/^[[:space:]]*//')
  [ "$kind" = branch ] && src="${src}  ← block never entered"
  unexecuted="${unexecuted}${f}:${ln}\t${src}"$'\n'
done <<< "$gaps"

# A throw arm of `??` / `?:` shares its line's record with the other arm, so no
# measurement can tell whether it ran — read the source instead. `case …:` /
# `default:` open statements, which BRDA already sees.
unmeasurable=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  hits=$(grep -nE '[?:][[:space:]]*\(?[[:space:]]*throw([^[:alnum:]_]|$)' "$f" 2>/dev/null) || continue
  while IFS= read -r h; do
    ln=${h%%:*}
    src=$(printf '%s' "${h#*:}" | sed 's/^[[:space:]]*//')
    case "$src" in case\ *|default:*|//*) continue ;; esac
    unmeasurable="${unmeasurable}${f}:${ln}\t${src}"$'\n'
  done <<< "$hits"
done <<< "$files"

# A pragma hides lines from lcov, so the per-line view above cannot see what it
# hid. Read the source instead: every pragma in a changed file is a finding.
pragmas=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  hits=$(grep -nE '//[[:space:]]*coverage(:ignore|-ignore)' "$f" 2>/dev/null) || continue
  while IFS= read -r h; do
    ln=${h%%:*}
    src=$(printf '%s' "${h#*:}" | sed 's/^[[:space:]]*//')
    pragmas="${pragmas}${f}:${ln}\t${src}"$'\n'
  done <<< "$hits"
done <<< "$files"

# A changed file with NO lcov record at all is not 0% — it is a file no test
# imported. That reads as "nothing to report" in every per-line view, which is
# why it is checked separately and reported first.
unreached=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  printf '%s\n' "$seen_files" | grep -qxF "$f" || unreached="${unreached}${f}"$'\n'
done <<< "$files"

# ...or a file with nothing to execute. The VM records every LOADED library that
# has a coverable line, even at zero hits, and omits the rest — measured: an enum,
# an interface, typedefs and consts, and a class whose only code is field
# initializers all leave no record. The probe tells the two apart: a test that
# only imports the absent files, run under coverage. A file still absent there
# has no executable line, so it is NO-CODE and does not block. Flutter runs only,
# since the lcov path is flutter's; a `part of` file cannot be imported and stays
# UNREACHED, as does everything when the probe itself fails to run.
nocode=""
if [ -n "$unreached" ] && [ "$1" = flutter ]; then
  pkg=$(sed -n 's/^name:[[:space:]]*//p' pubspec.yaml | head -1 | tr -d "\"' ")
  probe_dir="$root/build/plan-coverage-probe"
  mkdir -p "$probe_dir"
  probed=""
  {
    printf "import 'package:flutter_test/flutter_test.dart';\n"
    i=0
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      grep -qE '^[[:space:]]*part[[:space:]]+of[[:space:]]' "$f" && continue
      printf "import 'package:%s/%s' as p%d;\n" "$pkg" "${f#lib/}" "$i"
      probed="${probed}${f}"$'\n'; i=$((i + 1))
    done <<< "$unreached"
    printf "void main() => test('plan-coverage import probe', () {});\n"
  } > "$probe_dir/probe_test.dart"
  if [ -n "$probed" ] && flutter test "$probe_dir/probe_test.dart" --coverage \
       --coverage-path "$probe_dir/lcov.info" > "$probe_dir/log" 2>&1; then
    loaded=$(sed -n 's/^SF://p' "$probe_dir/lcov.info" | sed "s|^$root/||")
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      printf '%s\n' "$loaded" | grep -qxF "$f" || nocode="${nocode}${f}"$'\n'
    done <<< "$probed"
    unreached=$(printf '%s' "$unreached" | grep -vxF -f <(printf '%s' "$nocode") || true)
    [ -n "$unreached" ] && unreached="${unreached}"$'\n'
  elif [ -n "$probed" ]; then
    echo "plan-coverage: the import probe did not run ($probe_dir/log), so every absent file stays UNREACHED." >&2
  fi
fi

# --- report -----------------------------------------------------------------
n_unreached=$(printf '%s' "$unreached" | grep -c . || true)
n_gaps=$(printf '%s' "$unexecuted" | grep -c . || true)
n_prag=$(printf '%s' "$pragmas" | grep -c . || true)
n_unmeas=$(printf '%s' "$unmeasurable" | grep -c . || true)

# One verdict per file, shared by the terminal table and the markdown one:
# "<VERDICT>\t<gaps>\t<pragmas>".
verdict() {
  if printf '%s\n' "$unreached" | grep -qxF "$1"; then printf 'UNREACHED\t-\t-\n'; return; fi
  local g p v=PASS
  printf '%s\n' "$nocode" | grep -qxF "$1" && v=NO-CODE
  g=$(printf '%s%s' "$unexecuted" "$unmeasurable" | grep -c "^${1}:" || true)
  p=$(printf '%s' "$pragmas"    | grep -c "^${1}:" || true)
  if [ "$g" -gt 0 ] || [ "$p" -gt 0 ]; then v=FAIL; fi
  printf '%s\t%s\t%s\n' "$v" "$g" "$p"
}

echo
printf '%-10s %8s %8s  %s\n' VERDICT GAPS PRAGMAS FILE
while IFS= read -r f; do
  [ -n "$f" ] || continue
  IFS=$'\t' read -r v g p <<< "$(verdict "$f")"
  printf '%-10s %8s %8s  %s\n' "$v" "$g" "$p" "$f"
done <<< "$files"
echo "plan-coverage: elapsed ${elapsed}s."

if [ "$n_gaps" -gt 0 ]; then
  echo
  echo "Unexecuted:"
  printf '%b' "$unexecuted" | while IFS=$'\t' read -r loc src; do
    [ -n "$loc" ] && printf '  • %s  %s\n' "$loc" "$src"
  done
fi

if [ "$n_unmeas" -gt 0 ]; then
  echo
  echo "Unmeasurable (a throw arm of ?? / ?: — no record tells whether it ran):"
  printf '%b' "$unmeasurable" | while IFS=$'\t' read -r loc src; do
    [ -n "$loc" ] && printf '  • %s  %s\n' "$loc" "$src"
  done
fi

if [ "$n_prag" -gt 0 ]; then
  echo
  echo "Coverage pragmas (each hides lines from the measurement, or claims a retired exemption):"
  printf '%b' "$pragmas" | while IFS=$'\t' read -r loc src; do
    [ -n "$loc" ] && printf '  • %s  %s\n' "$loc" "$src"
  done
fi

# --- the markdown half, for the PR comment ----------------------------------
# Written every run, pass or fail, because a report that only appears on success
# is a report nobody can use to see what is still open. `plan-qa-report` reads
# this; it is keyed to HEAD so a stale section cannot be posted against a
# different tree.
# Into the caller's per-run directory when there is one (`plan-qa-report` makes
# one), a shared TMPDIR otherwise. Measured twice on one machine: another repo's
# run overwrote this file between `plan-qa-report`'s two halves — once caught by
# the `sha=` guard (the whole pass discarded), once not (a PR comment briefly
# carried another repo's table).
REPORT="${PLAN_QA_REPORT_DIR:-${TMPDIR:-/tmp}}/plan-qa-coverage.md"
head_sha=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)
{
  printf '<!-- plan-qa:coverage sha=%s -->\n' "$head_sha"
  printf '### Coverage — reach\n\n'
  printf 'Scope: %s changed file(s) vs `%s`, `%s`. Every changed line executed; no exemptions.\n\n' \
    "$count_files" "${base:---files}" "$*"
  printf '| Verdict | Gaps | Pragmas | File |\n|---|---:|---:|---|\n'
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    IFS=$'\t' read -r v g p <<< "$(verdict "$f")"
    case "$v" in PASS|NO-CODE) ;; *) v="**$v**" ;; esac
    printf '| %s | %s | %s | `%s` |\n' "$v" "$g" "$p" "$f"
  done <<< "$files"
  if [ "$n_unreached" -gt 0 ]; then
    printf '\n**UNREACHED means no test imported the file at all** — not 0%%%s, but absent from the coverage report entirely.\n' ''
  fi
  if [ -n "$nocode" ]; then
    printf '\nNO-CODE means the file has no executable line (declarations only): importing it alone still leaves no coverage record.\n'
  fi
  if [ "$n_gaps" -gt 0 ]; then
    printf '\n<details><summary>Unexecuted (%s)</summary>\n\n' "$n_gaps"
    printf '%b' "$unexecuted" | while IFS=$'\t' read -r loc src; do
      [ -n "$loc" ] && printf -- '- `%s` — `%s`\n' "$loc" "$src"
    done
    printf '\n</details>\n'
  fi
  if [ "$n_unmeas" -gt 0 ]; then
    printf '\n<details><summary>Unmeasurable throw arms (%s)</summary>\n\n' "$n_unmeas"
    printf '%b' "$unmeasurable" | while IFS=$'\t' read -r loc src; do
      [ -n "$loc" ] && printf -- '- `%s` — `%s`\n' "$loc" "$src"
    done
    printf '\n</details>\n'
  fi
  if [ "$n_prag" -gt 0 ]; then
    printf '\n<details><summary>Coverage pragmas (%s)</summary>\n\n' "$n_prag"
    printf '%b' "$pragmas" | while IFS=$'\t' read -r loc src; do
      [ -n "$loc" ] && printf -- '- `%s` — `%s`\n' "$loc" "$src"
    done
    printf '\n</details>\n'
  fi
} > "$REPORT"
echo "plan-coverage: report section — $REPORT"

if [ "$n_unreached" -gt 0 ] || [ "$n_gaps" -gt 0 ] || [ "$n_prag" -gt 0 ] || [ "$n_unmeas" -gt 0 ]; then
  cat >&2 <<EOF

plan-coverage: BLOCKED.
$( [ "$n_unreached" -gt 0 ] && printf '\n  %s changed file(s) appear NOWHERE in the coverage report — no test imports them.\n  That is not a low score; it is an unmeasured file, and mutation cannot see it\n  either (an unexecuted line produces no mutant to survive).\n' "$n_unreached" )
$( [ "$n_gaps" -gt 0 ] && printf '\n  %s unexecuted line(s). Add the test that runs each one. A line no test can\n  reach is a design finding — put it behind a seam a test can drive — and\n  there is no marker that passes it.\n' "$n_gaps" )
$( [ "$n_unmeas" -gt 0 ] && printf '\n  %s throw arm(s) of ?? / ?: that no coverage record can see. Rewrite each as a\n  statement (`if (x == null) throw …;`) so branch coverage measures it, then\n  test it.\n' "$n_unmeas" )
$( [ "$n_prag" -gt 0 ] && printf '\n  %s coverage pragma(s) in changed files. `coverage:ignore-*` removes lines from\n  the measurement before this gate reads it; `coverage-ignore:` is retired.\n  Remove them and let those lines be measured.\n' "$n_prag" )
EOF
  exit 1
fi
exit 0
