---
type: regex
pattern: 'Persist an `enum` with `toString\(\)`|must not be overridden'
flags: m
match: not_contains
arm: with-only
---
The old S4.1-dart, which persisted `toString()` and forbade overriding it, is gone.
