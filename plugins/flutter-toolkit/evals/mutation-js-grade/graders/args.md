---
type: regex
pattern: '^args: run --mutate src/empty\.ts,src/good\.ts,src/weak\.ts --reporters json,progress-append-only --concurrency 1 '
flags: m
arm: with-only
---
Takes only package source from the diff and runs Stryker in the package with concurrency 1.
