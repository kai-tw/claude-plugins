---
type: regex
pattern: '^a-before=0$'
flags: m
arm: with-only
---
[A2] Versions filed before the first build-* report don't count: brief-1 and brief-2 precede build-integration-1, brief-3 is the 1st after it, so the check passes.
