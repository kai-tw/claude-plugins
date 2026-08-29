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
trap 'rm -f "$raw"' EXIT

# The command's own exit status is ignored on purpose: red is the expected state
# here, and the classification below — not the runner's verdict — is the gate.
"$@" --reporter json > "$raw" 2>/dev/null

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
' "$raw" 2>/dev/null)

if [ -z "$rows" ]; then
  # Nothing failed at all. Green is always acceptable — this mode only ever
  # WIDENS what passes.
  echo "plan-test-first: suite green (no unimplemented stubs left)"
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
