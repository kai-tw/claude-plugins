---
type: regex
pattern: '^(locked|asleep): (flutter ran|rc=[^2])'
flags: m
match: not_contains
---
A refused run starts nothing and exits 2.
