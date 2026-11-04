---
type: regex
pattern: '^ga4 setup — dry run'
flags: m
match: contains
arm: with-only
---
ga4 setup without --commit only prints its steps.
