---
type: regex
pattern: '^workers=2$'
flags: m
arm: with-only
---
The launcher turns --workers 3 into 3 slots and rejects it when over budget.
