---
type: regex
pattern: '^args: run .* --incremental --incrementalFile \S+/plan-mutation-[0-9]+-stryker-web\.json'
flags: m
arm: with-only
---
Stryker keeps its results in an incremental file outside the repo, so a stopped run resumes.
