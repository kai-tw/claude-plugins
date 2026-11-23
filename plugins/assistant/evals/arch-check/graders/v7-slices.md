---
type: regex
pattern: '^b-slices=0$'
flags: m
arm: with-only
---
[V7] build-fix-1 and build-fix-2 with no verify-code between them are one round: verify-code-2 follows the 1st round, so its Logic fix does not fire (b).
