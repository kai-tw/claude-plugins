---
type: regex
pattern: '^gsc setup — dry run'
flags: m
match: contains
arm: with-only
---
gsc setup without --commit only prints its steps.
