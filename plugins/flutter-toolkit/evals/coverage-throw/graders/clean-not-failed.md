---
type: regex
pattern: '^FAIL .*lib/c\.dart$'
flags: m
match: not_contains
arm: with-only
---
A fully executed file is not marked FAIL.
