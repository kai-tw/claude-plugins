---
type: regex
pattern: '^skills/assistant/references/pr.md: CronCreate.*\bdate\b[^.]*(later|future|after)[^.]*(time|moment)[^.]*\.[^.]*(next|returned)[^.]*(run|fire|time)[^.]*year'
flags: mi
---
[M2] pr.md: before a one-time CronCreate run `date` and pick a later time from it; read the returned next run and confirm the year is this year.
