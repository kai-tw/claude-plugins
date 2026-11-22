---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/(tracker|brief)\.md|agents/builder\.md): .*(last|all)[^.]*slice[^.]*(clos|delet|done)[^.]*task row[^.]*(stays|remains|keeps|wait|([^a-z](never|not|no|none)|n.t)[^a-z])|task row[^.]*(stays|remains|([^a-z](never|not|no|none)|n.t)[^a-z])[^.]*clos[^.]*(last|all)[^.]*slice'
flags: mi
---
[B3] when every slice row is gone, the task row stays open for verify and the PR.
