---
type: regex
pattern: '^skills/assistant/SKILL\.md: .*dispatch[^.]*(carries|gives|names|passes|includes|with)[^.]*(estimat|hours)[^.]*start[^.]*([^a-z](never|not|no|none)|n.t)[^a-z][^.]*deadline|^skills/assistant/SKILL\.md: .*dispatch[^.]*(carries|gives|names|passes|includes|with)[^.]*start[^.]*(estimat|hours)[^.]*([^a-z](never|not|no|none)|n.t)[^a-z][^.]*deadline'
flags: mi
---
[F1] a builder dispatch carries the slice's estimated hours and start time, never the task's deadline.
