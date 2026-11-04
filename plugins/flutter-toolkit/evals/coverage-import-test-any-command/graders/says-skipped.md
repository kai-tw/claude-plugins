---
type: regex
pattern: '^dart: plan-coverage: not a Flutter package .* the import-only test did not run'
flags: m
arm: with-only
---
Outside a Flutter package, a skipped import-only test is said, not silent.
