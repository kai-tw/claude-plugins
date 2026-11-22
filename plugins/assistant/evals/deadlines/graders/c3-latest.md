---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/tracker\.md|agents/builder\.md): .*(differ|conflict|disagree|newer|latest)[^.]*(user|you|says|said)[^.]*(wins|overrides|replaces|over|latest|newest)[^.]*(date|Due)|(user.s|latest)[^.]*(word|date)[^.]*(replaces|overwrites|wins)'
flags: mi
---
[C3] when the user's date and the tracker date differ, the user's latest word is written over the tracker's date.
