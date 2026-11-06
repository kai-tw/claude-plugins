---
type: regex
pattern: 'next: schedule .asst-pr merged'
match: not_contains
arm: with-only
---
Turning a PR ready schedules no look at the merge.
