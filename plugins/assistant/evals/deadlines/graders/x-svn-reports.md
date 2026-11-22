---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/(tracker|brief)\.md|agents/builder\.md): .*svn[^.]*(filed )?(builder )?reports?[^.]*(first line|nam)[^.]*slice|on svn, the task.s filed builder reports'
match: not_contains
flags: mi
---
[B2] no rule reads done slices from svn's filed reports.
