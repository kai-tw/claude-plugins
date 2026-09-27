---
type: regex
pattern: '^bad-[a-z]+=[^2]'
flags: m
match: not_contains
arm: with-only
---
Every detaching command is blocked with exit 2.
