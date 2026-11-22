---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/tracker\.md|agents/builder\.md): .*(without|no|lacks?|missing)[^.]*Due[^.]*(column|field)?[^.]*(no deadline|without a? ?deadline|not? have a deadline)[^.]*(add|append)|(without|no|lacks?|missing)[^.]*Due[^.]*(no deadline|without a? ?deadline)'
flags: mi
---
[B1] a board with no Due column reads as no deadline; the column is added on first write.
