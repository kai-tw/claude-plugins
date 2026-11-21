---
type: regex
pattern: '^bad-pgrep-loop=hit$'
flags: m
arm: with-only
---
[D5] `while pgrep -f "<string>"` gets a warning: pgrep -f matches the shell running the loop itself, so the loop never ends and nothing errors.
