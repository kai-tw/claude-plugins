---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/(tracker|brief)\.md|agents/builder\.md): .*(split.s parent|parent of a split|split parent|request.s parent)[^.;]*(never dispatched|last sub-item)|(never dispatched|last sub-item)[^.;]*(split.s parent|parent of a split|split parent|request.s parent|only (to |for )?(a )?split)'
flags: mi
---
[B3] never dispatching a row with sub-items, and closing a parent with its last sub-item, hold only for a split's parent.
