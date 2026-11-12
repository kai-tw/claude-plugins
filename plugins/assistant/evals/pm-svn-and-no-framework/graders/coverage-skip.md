---
type: regex
pattern: '^coverage-skip=[1-9]'
flags: m
---
verify.md skips the coverage step without a test framework, never as a finding or fix round.
