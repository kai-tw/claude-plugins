---
type: regex
pattern: '^ok-pgrep-[a-z]+=noisy'
flags: m
match: not_contains
arm: with-only
---
[D5] `pgrep -x foo`, `pgrep -f foo | grep -v $$` and a plain `pgrep foo` get no warning.
