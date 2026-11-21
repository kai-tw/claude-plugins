---
type: regex
pattern: '(not|never|n.t|no need to|need not) (to )?cite[^.]*file:line[^.]*deploy|deploy[^.]*(needs?|takes?|carr(y|ies)) no `?file:line'
match: not_contains
flags: mi
---
[G2] A deploy-time value is never let off citing where the deploy sets it.
