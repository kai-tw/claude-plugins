---
type: regex
pattern: '^busy: rc=1$'
flags: m
arm: with-only
---
上限到了 run 還在，回 1 叫它再等一次；PLAN_TEST_SLOTS=0 也沒擋下它，證明 --wait 不占 slot。
