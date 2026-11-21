---
type: regex
pattern: '^skills/assistant/SKILL\.md: .*shared module[^.]*(no|without)[^.]*UI[^.]*(no|not|never)[^.]*UI (question|quest)'
flags: m
---
[R4] A task whose boundary is a shared module with no UI of its own asks no UI questions; the UI belongs to the task of the feature that uses the module.
