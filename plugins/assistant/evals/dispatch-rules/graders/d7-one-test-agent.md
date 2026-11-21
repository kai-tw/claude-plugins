---
type: regex
pattern: '^skills/assistant/SKILL\.md: .*(CI[^.]*same machine[^.]*one [^.]*(agent|dispatch)[^.]*tests?[^.]*at a time|one [^.]*agent[^.]*tests?[^.]*at a time[^.]*CI[^.]*same machine)'
flags: m
---
[D7] SKILL.md: when the project's CI runs on the same machine, only one agent that runs tests is dispatched at a time.
