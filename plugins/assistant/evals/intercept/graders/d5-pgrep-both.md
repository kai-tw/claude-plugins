---
type: regex
pattern: '^bad-pgrep-[a-z]+=miss'
flags: m
match: not_contains
arm: with-only
---
[D5] Both `while pgrep -f` loops are flagged, with or without output redirected.
