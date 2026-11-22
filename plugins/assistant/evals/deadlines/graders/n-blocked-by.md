---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/(tracker|brief)\.md|agents/builder\.md): .*slice[^.]*Next[^.]*(needs no|need not|without|no need|doesn.t need|does not need|not need)[^.]*Blocked by|slice[^.]*Blocked by[^.]*(optional|not required|not needed)'
flags: mi
---
[S5] a Next slice row needs no Blocked by, unlike a task row.
