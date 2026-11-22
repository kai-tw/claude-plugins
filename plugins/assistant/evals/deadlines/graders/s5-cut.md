---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/(tracker|brief)\.md|agents/builder\.md): .*slice[^.;]*(agree|approv|accept)[^.;]*(delet|remov)|(agree|approv|accept)[^.;]*cut[^.;]*slice[^.;]*(delet|remov)|(delet|remov)[^.;]*slice[^.;]*(agree|approv|accept)'
flags: mi
---
[S4] a slice the user agreed to cut is deleted.
