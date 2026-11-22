---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/(tracker|brief)\.md|agents/builder\.md): .*estimated size \(hours|task statement[^.]*hours per slice|hours per slice[^.]*task statement|task statement with its hours|(estimat|hours)[^.]*(from|into|in) the task statement|as the task statement gives them'
match: not_contains
flags: mi
---
[S5] the task statement carries no hours.
