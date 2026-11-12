---
type: regex
pattern: '^exempt=An .exempt. diff skips the code review: check it yourself — it changes only what the task statement names, and stays a typo, a constant or a log'
flags: m
arm: with-only
---
The assistant checks an exempt diff itself (references/verify.md): it changes only what the task statement names and stays a typo, a constant or a log; no line count.
