---
type: regex
pattern: '^o: .*(CronCreate|schedule|asst-pr merged)'
match: not_contains
flags: m
---
An open PR schedules no look at the merge.
