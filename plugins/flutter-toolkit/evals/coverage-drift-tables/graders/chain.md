---
type: regex
pattern: '• lib/rows\.dart:(6|7|10) '
match: not_contains
arm: with-only
---
The rest of a column getter's builder chain, and primaryKey, are not reported as unexecuted.
