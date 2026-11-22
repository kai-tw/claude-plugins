---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/tracker\.md|agents/builder\.md): .*((says?|states?|gives?|names?|asks?)[^.]*(date|deadline|by Friday)[^.]*(write|record|store|set|put)[^.]*(date (column|field)|Due)|(write|record|store|set|put)[^.]*(date|deadline)[^.]*(in|into|to)[^.]*(row.s )?(date (column|field)|Due))'
flags: mi
---
[S1] a date the user states is written to the row's date column (Notion Due, file board Due).
