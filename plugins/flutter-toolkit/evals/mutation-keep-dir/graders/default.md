---
type: regex
pattern: '^default: .*--incrementalFile .*/plan-mutation-[0-9]+-stryker-'
flags: m
arm: with-only
---
Without it, the run keeps them in the temp dir as before.
