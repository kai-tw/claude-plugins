---
type: regex
pattern: '^skills/assistant/references/tracker\.md: .*(interrupt[^.]*agent[^.]*(dead|died)|agent[^.]*(dead|died)[^.]*interrupt)'
flags: m
---
[D3] tracker.md scheduler pass: after a turn was interrupted, a background agent may already be dead.
