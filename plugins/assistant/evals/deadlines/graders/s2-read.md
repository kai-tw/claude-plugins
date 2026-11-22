---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/tracker\.md|agents/builder\.md): .*(every|each)[^.]*(pass|turn|round)[^.]*(read|compar)[^.]*(date (column|field)|Due|deadline)|(read|compar)[^.]*(date (column|field)|Due|deadline)[^.]*(every|each)[^.]*(pass|turn|round)'
flags: mi
---
[S2] each scheduler pass reads the deadline from the tracker row, so a PM edit is picked up next pass.
