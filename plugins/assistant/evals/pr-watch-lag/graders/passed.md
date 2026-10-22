---
type: regex
pattern: '^a=0$'
flags: m
arm: with-only
---
The watch exits 0 once a later read shows CI passed, not 3 at its timeout.
