---
type: regex
pattern: 'always\(\)'
match: not_contains
---
No `always()`: mutation is skipped when coverage fails, and stops when the workflow is cancelled.
