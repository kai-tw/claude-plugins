---
type: regex
pattern: '^(new|old): (run: rc=[^1]|stop: rc=[^0])'
flags: m
match: not_contains
---
The stopped run exits 1; --stop itself exits 0 once the run has ended.
