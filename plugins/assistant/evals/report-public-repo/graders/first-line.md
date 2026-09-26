---
type: regex
pattern: 'verify-code-1 posted to #9 \(first line only — repo not known private\)'
flags: m
arm: with-only
---
A public repo still gets a comment, so a missing leg shows on the PR, and stderr says it is the first line only.
