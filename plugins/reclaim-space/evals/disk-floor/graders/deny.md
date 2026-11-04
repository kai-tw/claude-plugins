---
type: regex
pattern: 'minimum free disk space is 999999G'
flags: m
match: contains
arm: with-only
---
Blocks when the minimum is too high and reports the minimum.
