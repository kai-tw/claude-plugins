---
type: regex
pattern: '^skills/assistant/references/tracker\.md: .*((scope|boundary)[^.]*Needs you[^.]*(unanswered|open|not (yet )?answered|awaits|waiting)[^.]*(nothing|no (row|work|sub-?items?|agent|task))[^.]*dispatch|(nothing|no (row|work|sub-?items?|agent|task))[^.]*dispatch[^.]*(scope|boundary)[^.]*Needs you[^.]*(unanswered|open|not (yet )?answered))'
flags: m
---
[E6] tracker.md: while a request has a scope `Needs you` unanswered, nothing under it is dispatched.
