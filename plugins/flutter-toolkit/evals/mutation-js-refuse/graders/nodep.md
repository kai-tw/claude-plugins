---
type: regex
pattern: '^nodep: .*does not depend on `@stryker-mutator/core`'
flags: m
arm: with-only
---
A package without Stryker is refused and the dependency to add is named.
