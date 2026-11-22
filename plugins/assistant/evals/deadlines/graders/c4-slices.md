---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/(tracker|brief)\.md|agents/builder\.md): .*(no deadline|without a deadline|has no deadline)[^.;]*(still|too|as well|all the same|anyway|regardless|alike) (gets?|has|have|goes|go|is|are|keeps?|puts?|uses?)[^.;]*slice|(no deadline|without a deadline|has no deadline)[^.;]*slice(.s)? rows?[^.;]*(too|as well|all the same|anyway|regardless|alike)|slice[^.;]*(no deadline|without a deadline)[^.;]*(too|as well|all the same|alike)|slice[^.;]*(every task|with or without a deadline|whether or not[^.]*deadline|even (without|with no) (a )?deadline)'
flags: mi
---
[C4] a task with no deadline still gets its slice rows.
