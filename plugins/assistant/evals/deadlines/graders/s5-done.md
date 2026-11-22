---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/(tracker|brief)\.md|agents/builder\.md): .*commit(s|ted)?[^.;]*checks? pass(es)?, (delete|remove) (the |its |that )?(slice )?row|(^|[.;:] )(delete|remove) (the|a) slice row (once|when|after)'
flags: mi
---
[S5] a slice row is deleted once the builder commits and the checks pass.
