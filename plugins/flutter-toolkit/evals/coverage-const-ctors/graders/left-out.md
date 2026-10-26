---
type: regex
pattern: '• lib/cc\.dart:(1|4|8|11|21) '
match: not_contains
arm: with-only
---
Const constructor declarations with no logic are not reported as unexecuted.
