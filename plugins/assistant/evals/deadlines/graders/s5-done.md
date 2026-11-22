---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/(tracker|brief)\.md|agents/builder\.md): .*slice[^.;]*(commit|commits|committed)[^.;]*(check|pass)[^.;]*(delete|remove)|(delete|remove)[^.;]*slice(.s)? row[^.;]*(once|when|after)[^.;]*(commit|pass)|(commit|commits|committed)[^.;]*checks? pass[^.;]*(delete|remove)[^.;]*(the |its |that )?(slice )?row'
flags: mi
---
[S5] a slice row is deleted once the builder commits and the checks pass.
