---
type: regex
pattern: '^trash-root: exit=[1-9] writes=0 msg=1$'
flags: m
arm: with-only
---
trash on a spec page with --root is refused as read-only, non-zero, and sends nothing.
