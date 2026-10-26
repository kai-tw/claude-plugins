---
type: regex
pattern: '^dart: plan-coverage: not a Flutter package .* the import probe did not run'
flags: m
arm: with-only
---
Outside a Flutter package, a skipped probe is said, not silent.
