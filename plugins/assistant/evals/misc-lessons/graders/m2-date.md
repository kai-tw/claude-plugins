---
type: regex
pattern: '^skills/assistant/references/pr\.md: .*\bdate\b.*(later|future|after).*(time|moment).*(next run|returned|returns).*year'
flags: mi
---
[M2] pr.md: before a one-time CronCreate run `date` and pick a later time from it; read the returned next run and confirm the year is this year.
