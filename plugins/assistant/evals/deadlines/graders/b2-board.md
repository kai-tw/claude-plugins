---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/(tracker|brief)\.md|agents/builder\.md): .*(slice(.s)? row|estimat|start time)[^.]*(tracker|board|slice(.s)? rows?)[^.]*([^a-z](never|not|no|none)|n.t)[^a-z][^.]*(memory|remember)|(every|each) pass[^.]*(read|take)[^.]*slice(.s)? rows?[^.]*(estimat|hours)[^.]*start'
flags: mi
---
[B2] after the conversation is compressed, the next pass reads the deadline, open slice rows, their estimates and start times from the tracker.
