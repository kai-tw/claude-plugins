#!/usr/bin/env bash
# Insert or REPLACE the team block in each role skill.
#
# One source, four files: writing-rules.md forbids one behaviour living in two
# wordings, and hand-editing four copies is four wordings waiting to drift.
#
# The block is fenced by explicit markers. A previous version stripped from the
# block's heading to the next heading instead, which silently deleted each
# role's Runtime contract — a blockquote with no heading between it and the
# block. Delimiters that depend on what happens to follow are not delimiters.
set -uo pipefail
P="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/team-block.md"
BEGIN='<!-- team-block:begin (generated — edit the source, not this copy) -->'
END='<!-- team-block:end -->'

for role in pm designer engineer qa; do
  f="$P/$role/SKILL.md"
  before_runtime=$(grep -c 'Runtime — you run in' "$f")
  before_lines=$(grep -c '' "$f")

  { printf '%s\n' "$BEGIN"; sed "s/@ROLE@/$role/g" "$SRC"; printf '%s\n' "$END"; } > "$SRC.$role"

  awk -v b="$BEGIN" -v e="$END" '
    index($0,b) { skip=1; next }
    index($0,e) { skip=0; next }
    !skip
  ' "$f" > "$f.stripped"

  awk -v bf="$SRC.$role" '
    /^---$/ { n++; print
              if (n==2) { while ((getline l < bf) > 0) print l; close(bf) }
              next }
    { print }
  ' "$f.stripped" > "$f.new" && mv "$f.new" "$f"
  rm -f "$f.stripped" "$SRC.$role"

  after_runtime=$(grep -c 'Runtime — you run in' "$f")
  # Exactly one copy of the section, always. 0.37.0 shipped a block written
  # before these markers existed, so the strip could not see it and this script
  # inserted a second, marked copy ABOVE it for two releases — two versions of
  # one rule, and the stale copy was the one that deadlocked the approval gates.
  # A generator that cannot detect its own earlier output is how that happens
  # twice; this is the assertion that would have caught it the first time.
  heads=$(grep -c '^## Working in a team$' "$f")
  [ "$heads" = 1 ] || { echo "  $role: ABORT — $heads copies of the section (an unmarked older block?)"; exit 1; }
  # The role's own contract must survive verbatim. qa has no Runtime blockquote,
  # so the assertion is "unchanged", not "present".
  [ "$before_runtime" = "$after_runtime" ] || { echo "  $role: ABORT — runtime block count $before_runtime -> $after_runtime"; exit 1; }

  printf '  %-9s %4s -> %4s lines   blocks:%s  asks-lead:%s  UNVERIFIED:%s  runtime:%s\n' \
    "$role" "$before_lines" "$(grep -c '' "$f")" \
    "$(grep -c 'team-block:begin' "$f")" "$(grep -c 'SendMessage.*lead' "$f")" \
    "$(grep -c '^UNVERIFIED' "$f")" "$after_runtime"
done
