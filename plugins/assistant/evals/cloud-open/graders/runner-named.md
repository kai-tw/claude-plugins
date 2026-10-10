---
type: regex
pattern: '^runner-named: title #42 - Nightly mutation$'
flags: m
arm: with-only
---
An explicit --name keeps the PR number in front: `#<n> - <--name>`.
