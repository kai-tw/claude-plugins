---
type: regex
pattern: '^comment-root: exit=[1-9] writes=0 msg=1$'
flags: m
arm: with-only
---
comment on a spec page with --root is refused as read-only, non-zero, and sends nothing.
