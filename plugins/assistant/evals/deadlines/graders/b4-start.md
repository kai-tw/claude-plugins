---
type: regex
pattern: '^agents/builder\.md: .*run .?date.? when you start, saved to .?\.claude/\.assistant/tasks/<slug>/<report kind>-<slice>\.start.?, then after each check or commit compare to it'
flags: mi
---
[B4] the builder saves the start time to a file named by report kind and slice, then compares to that file after each check or commit, so a compressed conversation still has it.
