#!/usr/bin/env bash
# Advisory scope-gate — scan a plan's surfaces and SUGGEST which of the five
# plan-graded dimensions the blueprint-reviewer panel should dispatch, and
# whether the Track-2 (security/privacy plan-mode) trigger fires.
#
# The five are the ones expensive to reverse once code exists; time, space,
# scalability, extendability, error handling, testability and startup order are
# graded on the diff by `code-reviewer` (see `notion-payload criteria
# engineering-plan`), so they are deliberately not suggested here.
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
hit 'cross-feature|setup_dependencies|register(Lazy|Factory|Singleton|FactoryParam)|new (use case|repository|abstraction)|portal|Overlay\.of|Draggable\.feedback|presentation.*presentation' \
  && echo "  - Coupling & Layering   (edge direction / new abstraction / portal scope)"
hit 'state shape|state holder|\bcubit\b|\bnotifier\b|persisted|shared mutable|concurren|\brace\b|account|sync path|StreamSubscription|re-entran' \
  && echo "  - Correctness & Race    (temporal: race / ordering / re-entrancy / guard)"
hit 'pubspec|dependencies:|\^[0-9]+\.[0-9]|新增套件|package_' \
  && echo "  - Package usage         (new / version-changed dependency; run the 1c package-explorer pre-pass)"
# Ownership is deliberately broad: a second source of truth reads as a clean
# addition, so a missed flag costs more than a spurious one. Any new field,
# entity, method or wrapper — and every projected/derived/mirrors phrasing —
# earns the dimension.
hit 'projected from|derived from|mirrors|新增 field|new field|wrapper|helper|manager|_service|canonical' \
  && echo "  - Abstraction / ownership (canonical home: does this datum already have an owner?)"
hit 'schemaVersion|persisted.?schema|migration|VersionedJson|metadata\.json|changed.*signature|wrapper.*delet|caller' \
  && echo "  - Migration & back-compat (schema / caller / wrapper-gate; run tool/version_diff.sh)"
echo

echo "## Track-2 (security/privacy plan-mode) trigger:"
if hit 'persist|egress|LogSystem\.[a-z]+\([^)]*\$|network|permission|plugin|deeplink|intent|\bauth\b|token|Drive|credential|collect'; then
  echo "  - TRIGGERED — route to Skill: security (mode=plan); + Skill: privacy when a"
  echo "    user-data collection surface is present. (Skill, not the agent — inherit the"
  echo "    dispatcher's foreground-gate + verdict-surface + refuse-relay.)"
else
  echo "  - not triggered — none of {persist, egress, log-interpolation, permission,"
  echo "    deeplink, auth} present in the plan."
fi
