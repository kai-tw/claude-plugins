---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/(tracker|brief)\.md|agents/builder\.md): .*slice[^.]*Blocked by[^.]*(parallel|at once|together|concurrent|same time)[^.]*(([^a-z](never|not|no|none)|n.t)[^a-z]|unchained)|(parallel|at once|together|concurrent|same time)[^.]*slice[^.]*([^a-z](never|not|no|none)|n.t)[^a-z][^.]*Blocked by|slice[^.]*([^a-z](never|not|no|none)|n.t)[^a-z][^.]*Blocked by[^.]*(parallel|at once|together|concurrent|same time)'
flags: mi
---
[S5] slices that run in order are chained by Blocked by; ones that can run together are not.
