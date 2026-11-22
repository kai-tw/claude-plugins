---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/(tracker|brief)\.md|agents/builder\.md): .*slice[^.]*(clos|delet|unblock|blocker)[^.]*([^a-z](never|not|no|none)|n.t)[^a-z][^.]*(turns?|moves?|becomes?|goes|starts?)[^.]*In Progress|slice[^.]*([^a-z](never|not|no|none)|n.t)[^a-z][^.]*(turns?|moves?|becomes?|goes|starts?)[^.]*In Progress[^.]*(clos|delet|unblock|blocker)'
flags: mi
---
[S5] closing one slice row never turns the next In Progress; only its dispatch does.
