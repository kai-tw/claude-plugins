---
type: regex
pattern: '^bad-pgrep-loop=hit$'
flags: m
arm: with-only
---
[D5] `while pgrep -f "<string>"` gets the `pgrep-f-wait` warning: pgrep -f also matches other shells waiting on the same string, so the loop may never end and nothing errors.
