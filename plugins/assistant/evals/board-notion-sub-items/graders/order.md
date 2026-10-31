---
type: regex
pattern: '^order=PATCH b,TRASH a,TRASH b,TRASH d$'
flags: m
arm: with-only
---
Trashing A unblocks B first; trashing B, the last sub-item, trashes D after it.
