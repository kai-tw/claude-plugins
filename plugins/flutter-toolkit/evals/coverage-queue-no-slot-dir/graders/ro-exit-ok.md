---
type: regex
pattern: '^read-only: rc=0$'
flags: m
arm: with-only
---
The run passes: a lock file that cannot be made does not stop a test run.
