---
type: regex
pattern: '^check-root: exit=[1-9] writes=0 msg=1$'
flags: m
arm: with-only
---
check on a spec page with --root is refused as read-only, non-zero, and sends nothing.
