---
type: regex
pattern: '^update-bare: exit=[1-9] writes=0 msg='
flags: m
arm: with-only
---
update on a spec page without --root fails and sends nothing.
