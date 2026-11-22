---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/(tracker|brief)\.md|agents/builder\.md): .*(hours|estimat)[^.]*only (in |on )?(the |its |a )?slice(.s)? row|(hours|estimat)[^.]*slice(.s)? row[^.]*([^a-z](never|not|no|none)|n.t)[^a-z][^.]*(task )?statement|statement[^.]*([^a-z](never|not|no|none)|n.t)[^a-z][^.]*hours|slice(.s)? row.s body[^.]*(only|sole|single) (home|place)|slice[^.]*(estimat|hours)[^.]*(no other place|nowhere else|only (home|place))'
flags: mi
---
[S5] the slice row is the only home of its hours; the task statement carries none.
