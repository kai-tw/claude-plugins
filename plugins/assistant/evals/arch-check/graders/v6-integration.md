---
type: regex
pattern: '^b-integration=0$'
flags: m
arm: with-only
---
[V6] An integration slice between fix rounds: verify-code-3 reviews build-integration-2 and has a Logic fix, but it is not the review after the 2nd build-fix round; verify-code-4 is, and it has no Logic fix, so the check passes.
