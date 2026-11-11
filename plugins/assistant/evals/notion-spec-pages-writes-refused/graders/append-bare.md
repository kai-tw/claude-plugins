---
type: regex
pattern: '^append-bare: exit=[1-9] writes=0 msg=1$'
flags: m
arm: with-only
---
append on a spec page without --root is refused as read-only, non-zero, and sends nothing.
