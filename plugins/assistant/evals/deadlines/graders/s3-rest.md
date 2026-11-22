---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/tracker\.md|agents/builder\.md): .*(earliest|soonest)[^.]*(Due|deadline|date)[^.]*(others?|rest|remaining)[^.]*Blocked by[^.]*(no (deadline|due)|without a? ?(deadline|due))[^.]*last|(earliest|soonest)[^.]*(Due|deadline|date)[^.]*(others?|rest|remaining)[^.]*Blocked by.*(no (deadline|due)|without a? ?(deadline|due))[^.]*(last|after)'
flags: mi
---
[S3] the other rows become Blocked by it; rows with no deadline sort last, same date by creation order.
