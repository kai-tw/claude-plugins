---
type: regex
pattern: '^wait-flag: rc=2$'
flags: m
arm: with-only
---
plan-mutation refuses --wait as an unknown flag instead of blocking.
