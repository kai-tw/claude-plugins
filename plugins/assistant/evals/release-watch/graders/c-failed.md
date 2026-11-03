---
type: regex
pattern: '^c: asst-pr: RELEASE FAILED — main is at [0-9a-f]{7}, but the run failed after that'
flags: m
arm: with-only
---
A run that fails after main moved is a failed deploy, not a refused push.
