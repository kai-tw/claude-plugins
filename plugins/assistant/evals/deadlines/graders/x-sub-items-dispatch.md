---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/(tracker|brief)\.md|agents/builder\.md): .*[(]a row with sub-items is never dispatched[)]'
match: not_contains
flags: mi
---
[B3] the never-dispatched rule no longer covers every row with sub-items, since a task row with slice rows is dispatched.
