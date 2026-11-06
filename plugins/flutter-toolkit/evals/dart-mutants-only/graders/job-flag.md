---
type: regex
pattern: '^job_flag=0$'
flags: m
arm: with-only
---
The mutation job does not pass --fail-on-survivors, which dart_mutants rejects without --review.
