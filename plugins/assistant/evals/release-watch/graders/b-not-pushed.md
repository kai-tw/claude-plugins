---
type: regex
pattern: '^b: asst-pr: RELEASE NOT PUSHED — main never moved to [0-9a-f]{7}\. The user pushes it, and that push deploys: git fetch origin && git push origin [0-9a-f]{40}:refs/heads/main$'
flags: m
arm: with-only
---
A failed run whose main never moved gives the user the push command.
