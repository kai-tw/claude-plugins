---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/(tracker|brief)\.md|agents/builder\.md): .*slice[^.]*(sub-item|.?Parent item.?|child row)[^.]*task row|task row[^.]*(sub-item|child row)[^.]*slice'
flags: mi
---
[S5] a slice row is a sub-item under its task row.
