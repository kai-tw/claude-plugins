---
type: regex
pattern: '^set-bare: exit=[1-9] writes=0 msg='
flags: m
arm: with-only
---
set on a spec page without --root fails and sends nothing.
