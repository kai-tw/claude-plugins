#!/usr/bin/env bash
# qa_report.sh — run BOTH test-strength gates once, post one report to the PR.
#
# WHY THIS EXISTS
#   `plan-coverage` and `plan-mutation` were each enforceable and neither was
#   enforced: the commit gate's four legs are codegen / lint+format /
#   plan-lint / review, and the ledger's gates are about plans, PRs and
#   review-dismissals. Both test-strength checks lived only in `qa/SKILL.md`
#   prose, and prose is the thing this plugin has already measured itself
#   failing to follow (see mutation.sh's LOW-SIGNAL note: only the exit code
#   reaches the habit).
#
#   This is the moment that makes them real. One command at the PR boundary
#   runs both, posts what they found where a human will see it, and records the
#   fact in the plan-cycle ledger so Gate 6 can block a PR that skipped it.
#
# WHY THE TWO STACK, AND WHY BOTH RUN EVEN WHEN THE FIRST FAILS
#   Reach comes first: a line no test executes produces no mutant, so mutation
#   cannot see it. But a report that stops at the first failure makes the second
#   round of work invisible — you fix the coverage gaps, re-run, and only then
#   discover the mutation debt. One pass, both answers.
#
# USAGE
#   plan-qa-report [--pr <N>] [--dry-run] [--files a.dart …] -- <test-command…>
#
#     --pr       the PR to comment on; inferred from the current branch if absent
#     --dry-run  compose and print, post nothing
#
# EXIT
#   0  both gates green (and, when a PR was resolved, the comment is posted)
#   1  at least one gate blocked — the report is still composed and still posted
#   2  nothing was measured by one of them, so there is no report to speak of

set -uo pipefail

PR=""; DRY=0; PASSTHRU=()
while [ $# -gt 0 ]; do
  case "$1" in
    --pr)      PR="${2:-}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --files)   PASSTHRU+=("--files"); shift
               while [ $# -gt 0 ] && [ "$1" != "--" ]; do PASSTHRU+=("$1"); shift; done ;;
    --)        shift; break ;;
    -h|--help) sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*)        echo "plan-qa-report: unknown flag '$1'. The test command goes after \`--\`." >&2; exit 2 ;;
    *)         break ;;
  esac
done
[ $# -gt 0 ] || { echo "plan-qa-report: need a test command (e.g. plan-qa-report -- flutter test test/features/trash)" >&2; exit 2; }

root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "plan-qa-report: not in a git repo" >&2; exit 2; }
cd "$root" || exit 2
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

sha=$(git rev-parse --short HEAD)
T="${TMPDIR:-/tmp}"

# --- run both ---------------------------------------------------------------
# Directly, not via the bin/ launchers: this script is already inside a slot
# (its own launcher took one), and going through them would make each gate
# queue for a second one behind itself.
echo "=== plan-qa-report: coverage ==="
bash "$here/coverage.sh" "${PASSTHRU[@]}" -- "$@"; cov_rc=$?
echo
echo "=== plan-qa-report: mutation ==="
bash "$here/mutation.sh" "${PASSTHRU[@]}" -- "$@"; mut_rc=$?

# exit 2 from either means the tool never measured — a red suite, a missing
# engine, no coverage written. There is no report to post about a run that did
# not happen, and posting one would put a green-looking table on a PR that was
# never graded.
if [ "$cov_rc" -eq 2 ] || [ "$mut_rc" -eq 2 ]; then
  echo >&2
  echo "plan-qa-report: NOTHING WAS MEASURED (coverage exit ${cov_rc}, mutation exit ${mut_rc}) — no report posted." >&2
  echo "plan-qa-report: fix what the failing gate printed above and run this again. A missing report is not a passing one." >&2
  exit 2
fi

cov_md="$T/plan-qa-coverage.md"; mut_md="$T/plan-qa-mutation.md"
for f in "$cov_md" "$mut_md"; do
  [ -s "$f" ] || { echo "plan-qa-report: $f is missing — the gate ran but wrote no section." >&2; exit 2; }
  # Both sections must be about THIS tree. A mutation pass is long enough for a
  # commit to land underneath it — another session, a hook, a rebase — and the
  # two sections would then describe two different trees while reading as one
  # verdict. Cheap to check, and the failure it prevents is invisible.
  grep -q "sha=$sha" "$f" || {
    echo "plan-qa-report: $f was written against a different commit (this HEAD is $sha) — re-run, do not post a stale verdict." >&2
    exit 2
  }
done

# --- compose ----------------------------------------------------------------
verdict="✅ **Both gates green.**"
[ "$cov_rc" -ne 0 ] && [ "$mut_rc" -ne 0 ] && verdict="❌ **Both gates blocked.**"
[ "$cov_rc" -ne 0 ] && [ "$mut_rc" -eq 0 ] && verdict="❌ **Coverage blocked**, mutation green."
[ "$cov_rc" -eq 0 ] && [ "$mut_rc" -ne 0 ] && verdict="❌ **Mutation blocked**, coverage green."

body="$T/plan-qa-report.md"
{
  # The marker is what lets a re-run EDIT this comment instead of stacking a
  # new one under it. A PR that gets four rounds of fixes should end with one
  # comment showing where it landed, not four showing where it has been.
  printf '<!-- plan-qa -->\n'
  printf '## Test-strength report — `%s`\n\n' "$sha"
  printf '%s\n\n' "$verdict"
  printf 'Two checks that stack rather than substitute: **coverage** asks whether the changed lines RAN, **mutation** asks whether anything would notice if they were wrong. A line no test executes produces no mutant, so a green mutation score over an unreached file means nothing.\n\n'
  cat "$cov_md"; printf '\n'
  cat "$mut_md"; printf '\n'
  printf -- '---\n<sub>`plan-qa-report` · plan-cycle</sub>\n'
} > "$body"

echo
echo "plan-qa-report: composed — $body"

# --- post -------------------------------------------------------------------
rc=0
if [ "$cov_rc" -ne 0 ] || [ "$mut_rc" -ne 0 ]; then rc=1; fi

if [ "$DRY" -eq 1 ]; then
  echo "plan-qa-report: --dry-run, nothing posted. Body:"; echo; cat "$body"; exit "$rc"
fi

command -v gh >/dev/null 2>&1 || {
  echo "plan-qa-report: \`gh\` is not on PATH — the report is at $body, post it by hand." >&2
  exit "$rc"
}
if [ -z "$PR" ]; then
  PR=$(gh pr view --json number -q .number 2>/dev/null)
fi
if [ -z "$PR" ]; then
  echo "plan-qa-report: no PR for this branch yet — the report is at $body and will post on the next run once the PR exists."
  exit "$rc"
fi

# Edit the existing plan-qa comment when there is one. `--edit-last` is NOT used:
# it edits the author's last comment whatever it is, which on a PR the agent has
# also been discussing in would overwrite a reply.
existing=$(gh pr view "$PR" --json comments \
  -q '[.comments[] | select(.body | contains("<!-- plan-qa -->")) | .url] | last // empty' 2>/dev/null)
cid=$(printf '%s' "$existing" | sed -n 's/.*#issuecomment-\([0-9]*\)$/\1/p')

if [ -n "$cid" ]; then
  repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
  if gh api --method PATCH "repos/$repo/issues/comments/$cid" -F body=@"$body" >/dev/null 2>&1; then
    echo "plan-qa-report: updated $existing"
  else
    echo "plan-qa-report: could not edit the existing comment; posting a new one." >&2
    gh pr comment "$PR" --body-file "$body"
  fi
else
  gh pr comment "$PR" --body-file "$body"
fi

# --- record -------------------------------------------------------------------
# Only on green, and only after the comment landed: the ledger fact means "both
# gates passed on this tree and a human can see the evidence", not "the command
# was typed". Gate 6 reads it.
if [ "$rc" -eq 0 ]; then
  gate="$here/../../../bin/plan-cycle"
  [ -x "$gate" ] && bash "$gate" qa-green "$(git rev-parse HEAD)" 2>/dev/null
fi

exit "$rc"
