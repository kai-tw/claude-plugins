---
type: regex
pattern: '^b1-missing-none=1$'
flags: m
arm: with-only
---
[B1] project.md reads a missing `architecture:` field as `none`, so an existing project is never asked for it.
