#!/usr/bin/env bash
# Advisory scope-gate — scan a plan's surfaces and SUGGEST which of the two
# plan-graded dimensions the engineer-plan-reviewer should walk.
#
# The two are the ones asking "should this exist at all", which the diff can
# no longer answer: by then it exists and it looks fine. Everything else —
# time, space, scalability, extendability, coupling, correctness/race, error
# handling, testability, startup order — is graded on the diff by
# `code-reviewer` (see `notion-payload criteria engineering-plan`), so it is
# deliberately not suggested here.
#
# ADVISORY ONLY. This is a keyword heuristic; the engineer confirms the actual
# set. It exists so the deterministic surface-scan isn't re-done by hand each
# cycle — a dimension is never *dropped* just because this script didn't flag it.
#
# Usage: scope_gate.sh <engineering-plan.md>
set -uo pipefail

plan="${1:-}"
if [ -z "$plan" ] || [ ! -f "$plan" ]; then
  echo "usage: plan-scope-gate <engineering-plan.md>" >&2
  exit 2
fi

hit() { grep -qiE "$1" "$plan" 2>/dev/null; }

echo "## Suggested plan dimensions (engineer confirms; never drop a flagged one):"
hit 'pubspec|dependencies:|\^[0-9]+\.[0-9]|新增套件|package_' \
  && echo "  - (not a dimension) new / version-changed dependency → spawn the package-explorer
    pre-pass; its verdict is carried into the review, not re-judged"
# Ownership is deliberately broad: a second source of truth reads as a clean
# addition, so a missed flag costs more than a spurious one. Any new field,
# entity, method or wrapper — and every projected/derived/mirrors phrasing —
# earns the dimension. The role-noun list exists because the measured escape
# was a plan that used none of the original keywords: a `FooCoordinator` with
# no "wrapper/helper/manager" in sight never got dimension 10 suggested. A
# ScrollController mention triggering this spuriously is the accepted cost.
hit 'projected from|derived from|mirrors|新增 field|new field|new class|新增 class|wrapper|helper|manager|coordinator|controller|registry|orchestrator|handler|engine|_service|service\b|store\b|canonical' \
  && echo "  - Abstraction / ownership (canonical home: does this datum already have an owner?)"
hit 'schemaVersion|persisted.?schema|migration|VersionedJson|metadata\.json|changed.*signature|wrapper.*delet|caller' \
  && echo "  - Migration & back-compat (schema / caller / wrapper-gate; run version-diff)"
echo
echo "## Security / privacy: not gated here — they read the diff's real sinks,"
echo "   not the plan's claim about them (plan/SKILL.md §audit matrix, code row)."
