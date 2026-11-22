---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/(tracker|brief)\.md|agents/builder\.md): .*(earliest|by .?Due|Due.? order)[^.]*(only[^.]*task rows|task rows only|([^a-z](never|not|no|none)|n.t)[^a-z][^.]*slice)|slice(.s)? rows?[^.]*([^a-z](never|not|no|none)|n.t)[^a-z][^.]*(earliest|.?Due.? order|sort)'
flags: mi
---
[S3] the earliest-Due order counts task rows only, never slice rows.
