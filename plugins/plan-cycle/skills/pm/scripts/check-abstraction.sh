#!/usr/bin/env bash
# Product plan abstraction checker.
#
# Scans a plan file for engineering vocabulary that must not appear in product
# plans: state-holder / repository class names, file extensions, line-number
# references, and framework identifiers. A plan that passes is safe to save;
# one that fails contains implementation detail that pre-commits engineering
# decisions and rots when the code is renamed.
#
# The judgment half (rewriting offending lines at the product abstraction)
# lives in the PM role's Phase 5. This script is the mechanical gate.
#
# PROJECT-SPECIFIC VOCABULARY
#   The base pattern below covers vocabulary shared across Flutter projects. A
#   project's own leaky terms — the SDKs it wraps, its house class suffixes —
#   belong to that project, so they are read from an optional file rather than
#   baked in here:
#
#     .claude/pm-vocabulary.txt
#
#   One extended-regex fragment per line; blank lines and #-comments ignored.
#   The fragments are OR'd onto the base pattern. Absent file → base only.
#
# Usage:
#   pm-abstraction-check <plan-file>
#
# Exit codes:
#   0   Clean — no violations found.
#   1   Violations found — offending lines printed to stderr.
#   2   Usage error (wrong number of arguments, file not found).

set -euo pipefail

ok()  { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
err() { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; }
die() { err "$*"; exit 2; }

usage() {
  awk '/^# Usage:/,/^$/' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

[ $# -eq 1 ] || usage
plan_file="$1"
[ -f "$plan_file" ] || die "File not found: $plan_file"

# Engineering vocabulary that leaks in every Flutter project regardless of its
# state-management choice. Keep in sync with Phase 5 §"Self-check" in SKILL.md.
# Cubit/Bloc and Notifier/Provider are both listed on purpose: the checker must
# stay correct whichever a project picked, and naming one would quietly wave
# the other through.
pattern='Exception|Cubit|Bloc|Notifier|Provider|Repository|DataSource|UseCase|\.dart|\.swift|\.kt|\.ts[^t]|:[0-9]+'

# Project-supplied additions, if any.
vocab_file="${CLAUDE_PROJECT_DIR:-.}/.claude/pm-vocabulary.txt"
if [ -f "$vocab_file" ]; then
  extra=$(grep -vE '^\s*(#|$)' "$vocab_file" | paste -sd'|' -)
  [ -n "$extra" ] && pattern="$pattern|$extra"
fi

matches=$(grep -En "$pattern" "$plan_file" 2>/dev/null || true)

if [ -z "$matches" ]; then
  ok "Clean — no engineering vocabulary found in $(basename "$plan_file")"
  exit 0
else
  err "Engineering vocabulary found in $(basename "$plan_file") — rewrite at product abstraction before saving:"
  printf '%s\n' "$matches" >&2
  exit 1
fi
