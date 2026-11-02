---
type: regex
pattern: '^gh pr create --draft --base staging --head task/x'
flags: m
arm: with-only
---
The task PR is opened into base_branch, not the default branch.
