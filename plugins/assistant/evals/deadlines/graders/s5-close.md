---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/(tracker|brief)\.md|agents/builder\.md): .*task row (closes|is closed|is deleted)[^.;]*slice(.s)? rows?[^.;]*(are |get |go )?(deleted|removed|with it)|slice(.s)? rows?[^.;]*(are |get )?(deleted|removed)[^.;]*(with|when)[^.;]*task row[^.;]*(clos|delet)|(clos|delet)(e|es|ing)? (a |the |its )?task row[^.;]*(delet|remov)[^.;]*slice(.s)? rows?'
flags: mi
---
[S5] when the task row closes, its slice rows are deleted with it.
