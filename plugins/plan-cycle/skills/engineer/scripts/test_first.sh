#!/usr/bin/env bash
# test_first.sh — commit-gate leg 2, in test-first mode.
#
# WHY THIS EXISTS
#   Under TDD the test-authoring stage ends with a suite that is red BY
#   CONSTRUCTION: the contract exists as stubs, nothing is implemented. Leg 2 of
#   the commit gate is "tests green — a failing test blocks the commit", so that
#   suite cannot be committed, and the whole stage would have to sit uncommitted
#   through implementation.
#
#   The fix is a narrower leg 2, not an exemption from it. The gate's purpose is
#   "no UNEXPLAINED red", and in this stage exactly one red is explained: a stub
#   that has not been implemented yet. Everything else — a real assertion
#   failure, a broken existing test, a compile error, a timeout — still blocks.
#   Skipping leg 2 outright would have surrendered all of that.
#
# HOW IT DECIDES  (measured against the real reporter, not assumed)
#   `--reporter json` emits, per test, a `testDone` carrying `result`, and for a
#   failure an `error` event carrying the message. The two reds are already
#   distinct there, which is what makes this checkable at all:
#
#     result "error"    + error "UnimplementedError…"  → the stub. Expected.
#     result "error"    + anything else                → a real throw. Blocks.
#     result "failure"                                 → an assertion failed. Blocks.
#
#   `hidden` marks the synthetic loading/compile entries; a compile error surfaces
#   as a non-success on one of those and blocks like anything else.
#
#   THE STUB CLASSIFICATION IS A PREFIX MATCH on the error message. Any framework
#   that wraps or reformats the throw before reporting it — so the message no
#   longer STARTS with `UnimplementedError` — classifies BLOCK, not STUB. That is
#   the safe direction (a gate that fails closed), but it has a consequence worth
#   knowing before you write the plan: a conformance item that can only be
#   asserted by mounting a widget may not be expressible as a red-by-stub, which
#   biases the plan toward extracting pure units. Reported for Flutter's
#   `pumpWidget` and NOT verified here.
#
# USAGE
#   plan-test-first flutter test [<path>…]
#   plan-test-first dart test    [<path>…]
#
#   The test command is passed through verbatim; `--reporter json` is appended.
#   Exit 0 = the only failures are unimplemented stubs (commit may proceed under
#   test-first). Exit 1 = something else is red. Exit 2 = bad usage / no jq.

set -uo pipefail

[ "$#" -gt 0 ] || {
  echo "usage: plan-test-first <test-command…>    e.g. plan-test-first flutter test" >&2
  exit 2
}
command -v jq >/dev/null 2>&1 || { echo "plan-test-first: jq is required" >&2; exit 2; }

raw=$(mktemp) || exit 2
trap 'rm -f "$raw" "$raw.err" "$raw.json" "$raw.jqerr"' EXIT

# The command's own exit status is ignored on purpose: red is the expected state
# here, and the classification below — not the runner's verdict — is the gate.
"$@" --reporter json > "$raw" 2>"$raw.err"

# STDOUT is not pure JSONL. Flutter prints dependency resolution ahead of the
# stream — measured at ~152 lines on Flutter 3.44 — and jq dies on line 1.
grep '^{' "$raw" > "$raw.json" 2>/dev/null || true

# THE REPORT HAS TO EXIST BEFORE ITS EMPTINESS MEANS ANYTHING.
#
# Every read below treats "no rows" as "nothing failed", which is only true if a
# report was actually parsed. Two ways it is not, and both used to print green:
# jq dying on the preamble (fixed above), and a run that emitted no JSON at all —
# command failed to launch, wrong directory, the runner erroring before it
# starts. Checking jq's exit status does not catch the second, because jq exits 0
# on empty input; that IS its honest status. So assert the presence of testDone
# events positively rather than inferring health from the absence of an error.
done_n=$(jq -s '[.[] | select(.type=="testDone")] | length' "$raw.json" 2>"$raw.jqerr")
case "$done_n" in ''|*[!0-9]*) done_n=-1 ;; esac
if [ "$done_n" -le 0 ]; then
  cat >&2 <<EOF
plan-test-first: NO TEST REPORT. The command produced no testDone events, so no
test was observed to pass or fail. This is not a green suite — nothing ran, or
nothing that ran was reported.

  command: $*
$( [ "$done_n" -lt 0 ] && printf '  the report could not be parsed:\n%s\n' "$(head -5 "$raw.jqerr" | sed 's/^/    /')" )
$( [ -s "$raw.err" ] && printf '  it wrote to stderr:\n%s\n' "$(head -10 "$raw.err" | sed 's/^/    /')" )
$( [ -s "$raw" ] && printf '  first lines of its output:\n%s\n' "$(head -5 "$raw" | sed 's/^/    /')" )
EOF
  exit 2
fi

# jq -s slurps the JSONL stream. Build id→name/url/error maps, then list every
# non-success test with the fields needed to classify and to report it.
# `-r` is load-bearing: without it @tsv comes back JSON-quoted with literal \t,
# awk's -F'\t' never splits, and every row classifies as neither STUB nor BLOCK —
# which reads as "nothing is wrong" and lets a real failure through.
rows=$(jq -s -r '
  (reduce (.[] | select(.type=="testStart")) as $t ({}; .[$t.test.id|tostring] = $t.test.name))  as $names
| (reduce (.[] | select(.type=="testStart")) as $t ({}; .[$t.test.id|tostring] = ($t.test.url // "")))  as $urls
| (reduce (.[] | select(.type=="error"))     as $e ({}; .[$e.testID|tostring] = $e.error))       as $errs
| [ .[]
    | select(.type=="testDone" and .result != "success")
    | { result: .result,
        name:  ($names[.testID|tostring] // "?"),
        url:   ($urls[.testID|tostring]  // ""),
        err:   ($errs[.testID|tostring]  // "") } ]
| .[]
| [ .result,
    (if (.result == "error" and (.err | startswith("UnimplementedError"))) then "STUB" else "BLOCK" end),
    .name,
    (.err | split("\n")[0]) ]
| @tsv
' "$raw.json" 2>/dev/null)

if [ -z "$rows" ]; then
  # Nothing failed, out of ${done_n} test(s) that actually reported. The count is
  # what makes this branch safe to read as green — without it, "no rows" also
  # means "no report", which is the fail-open the check above exists to stop.
  echo "plan-test-first: suite green — ${done_n} test(s) reported, none failed (no unimplemented stubs left)"
  exit 0
fi

stubs=$(printf '%s\n' "$rows" | awk -F'\t' '$2=="STUB"'  | wc -l | tr -d ' ')
block=$(printf '%s\n' "$rows" | awk -F'\t' '$2=="BLOCK"')

if [ -n "$block" ]; then
  cat >&2 <<EOF
plan-test-first: BLOCKED — red that is not an unimplemented stub.

$(printf '%s\n' "$block" | awk -F'\t' '{ printf "  • [%s] %s\n      %s\n", $1, $3, $4 }')

Unimplemented stubs in this run: ${stubs}. Those are the expected red of the
test-first stage. The failures above are not — an assertion that genuinely does
not hold, a throw that is not UnimplementedError, or a suite that did not load.
Fix them; leg 2 is only widened for stubs, never switched off.
EOF
  exit 1
fi

echo "plan-test-first: ${stubs} unimplemented stub(s), nothing else red — leg 2 satisfied for the test-first stage."
printf '%s\n' "$rows" | awk -F'\t' '{ printf "  • %s\n", $3 }'
exit 0
