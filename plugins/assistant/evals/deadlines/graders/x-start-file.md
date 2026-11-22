---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/(tracker|brief)\.md|agents/builder\.md): .*[a-z>]\.start([^a-z]|$)|start(-time)? file'
match: not_contains
flags: mi
---
[B2] no start-time file: the slice row's Current state holds the start.
