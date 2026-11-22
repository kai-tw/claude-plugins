---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/(tracker|brief)\.md|agents/builder\.md): .*git log[^.]*slice|slice[^.]*git log'
match: not_contains
flags: mi
---
[B2] no rule reads done slices from `git log`; the tracker holds them.
