---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/(tracker|brief)\.md|agents/builder\.md): .*(remaining|left)[^.]*slice(.s)? rows?[^.]*(In Progress[^.]*(minus|less|subtract|deduct|without)[^.]*(start|elapsed|since)|(minus|less|subtract|deduct)[^.]*(elapsed|since|start)[^.]*In Progress)'
flags: mi
---
[S4] remaining hours are the estimates of the open slice rows, an In Progress one minus the time since its start.
