---
type: regex
pattern: 'missing or stale: verify-code\(none\) verify-coverage\(none\) verify-text\(none\)'
flags: m
arm: with-only
---
With no reports it lists every required verify leg: coverage is set and the diff touches ui_strings, so text is required too.
