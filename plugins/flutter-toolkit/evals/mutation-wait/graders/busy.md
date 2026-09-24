---
type: regex
pattern: '^busy: rc=1$'
flags: m
arm: with-only
---
Run still alive at the limit returns 1 to wait again; PLAN_TEST_SLOTS=0 did not block it, proving --wait takes no slot.
