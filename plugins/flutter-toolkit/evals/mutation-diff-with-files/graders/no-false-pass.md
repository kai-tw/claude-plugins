---
type: regex
pattern: 'only deletes lines'
flags: m
match: not_contains
arm: with-only
---
It never reports that the diff only deletes lines.
