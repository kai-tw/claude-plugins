---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/tracker\.md|agents/builder\.md): .*(one task|single task|only one|one at a time)[^.]*(earliest|soonest)[^.]*(Due|deadline|date)[^.]*In Progress|(earliest|soonest)[^.]*(Due|deadline|date)[^.]*In Progress[^.]*(one task|single task|only one|one at a time)'
flags: mi
---
[S3] with only one task runnable, the row with the earliest due date goes In Progress.
