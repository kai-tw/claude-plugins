---
type: regex
pattern: '--max-minutes'
match: not_contains
---
No `--max-minutes`: it stops a run on the engine's time estimate, which is often wrong; the job's timeout is the only cap.
