---
type: regex
pattern: '^watchdog: still running'
flags: m
match: not_contains
---
A workflow on GitHub-hosted runners that keeps running doesn't keep this runner up.
