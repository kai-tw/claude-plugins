---
type: regex
pattern: '^r: args: .*--lines lib/a\.dart:2-3 --per-line 1 '
flags: m
arm: with-only
---
Only the changed lines are mutated, one mutant a line.
