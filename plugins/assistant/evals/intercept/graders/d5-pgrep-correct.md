---
type: regex
pattern: '^ok-pgrep-[a-z]+=noisy'
flags: m
match: not_contains
arm: with-only
---
[D5] Loops on `pgrep -f "[x].json"` and `pgrep -f "^node server.js"`, and `while kill -0 $pid`, get no warning.
