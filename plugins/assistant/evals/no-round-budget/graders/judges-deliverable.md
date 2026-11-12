---
type: regex
pattern: '^round-judged=11$'
flags: m
arm: with-only
---
Instead of a cap the assistant judges whether the current state can be delivered: references/verify.md turns the remaining `fix` findings into one `Needs you` line when another round won't settle them, and SKILL.md delivers what it judges deliverable and sends what it can't resolve to the user.
