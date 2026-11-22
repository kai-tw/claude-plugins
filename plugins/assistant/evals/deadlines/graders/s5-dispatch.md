---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/(tracker|brief)\.md|agents/builder\.md): .*(dispatch[^.]*In Progress|In Progress[^.]*dispatch)[^.]*(start|time)[^.]*Current state|(dispatch[^.]*In Progress|In Progress[^.]*dispatch)[^.]*Current state[^.]*(start|time|date)'
flags: mi
---
[S5] dispatching a slice's builder turns its row In Progress, the start date and time in its Current state.
