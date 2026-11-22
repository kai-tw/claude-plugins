---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/(tracker|brief)\.md|agents/builder\.md): .*slice[^.]*([^a-z](never|not|no|instead of|rather than)[^a-z])[^.]*(sub-issue|separate issue|own issue|new issue)'
flags: mi
---
[S5] a slice never gets its own GitHub issue.
