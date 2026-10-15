---
type: regex
pattern: '^at-merge=3$'
flags: m
arm: with-only
---
plan-mutation runs on the merge commit every time, not on the checkout it started from.
