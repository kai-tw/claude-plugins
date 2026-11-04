---
type: regex
pattern: 'NEW session|restart'
match: not_contains
flags: i
arm: with-only
---
The notice doesn't hard-code a restart as the way to load the update.
