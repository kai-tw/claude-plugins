---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/(tracker|brief)\.md|agents/builder\.md): .*slice(.s)? row[^.]*body[^.]*(holds|carries|has|gives|states|writes|keeps|with)[^.]*(estimat|hours)|(estimat|hours)[^.]*(in|into) (the |its |each |a )?(slice(.s)? row.s body|body of (the |its |each |a )?slice(.s)? row)|(write|put|record|keep)[^.]*(estimat|hours)[^.]*slice(.s)? row[^.]*body|slice[^.]*(in|into) (its|the) (row.s )?body,? (the |its )?(estimat|hours)'
flags: mi
---
[S5] a slice row's body holds its estimated hours.
