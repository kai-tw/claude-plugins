---
type: regex
pattern: 'floor'
flags: m
match: not_contains
arm: with-only
---
The block message says "minimum free disk space", not "floor" (the env var name is upper case and does not match).
