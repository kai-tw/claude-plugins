---
type: regex
pattern: '^trash-bare: exit=[1-9] writes=0 msg=1$'
flags: m
arm: with-only
---
trash on a spec page without --root is refused as read-only, non-zero, and sends nothing.
