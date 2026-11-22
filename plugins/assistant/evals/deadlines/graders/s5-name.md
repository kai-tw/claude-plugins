---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/(tracker|brief)\.md|agents/builder\.md): .*slice[^.]*Name[^.]*<(task[ -]?)?slug>/<[a-z ]+>|Name[^.]*<(task[ -]?)?slug>/<[a-z ]+>[^.]*slice'
flags: mi
---
[S5] a slice row is named `<slug>/<n> <what>`.
