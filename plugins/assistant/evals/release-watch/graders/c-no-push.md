---
type: regex
pattern: '^c: .*git push origin'
flags: m
match: not_contains
arm: with-only
---
A failed deploy offers no push command: main already moved.
