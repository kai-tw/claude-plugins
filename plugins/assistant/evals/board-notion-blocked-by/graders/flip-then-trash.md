---
type: regex
pattern: '^order=PATCH b,TRASH a$'
flags: m
arm: with-only
---
Only B (whose last blocker was A) turns In Progress, and before A is trashed; C, still blocked by D, isn't touched.
