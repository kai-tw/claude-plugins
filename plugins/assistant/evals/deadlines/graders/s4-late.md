---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/tracker\.md|agents/builder\.md): .*(remaining|left)[^.]*(hours?|estimate)[^.]*(deadline|due)[^.]*Needs you[^.]*(finish|completion|done)[^.]*(date|day)[^.]*(cut|trim|shrink|narrow|scope)|(deadline|due)[^.]*(remaining|left)[^.]*(hours?|estimate)[^.]*Needs you[^.]*(finish|completion|done)[^.]*(date|day)[^.]*(cut|trim|shrink|narrow|scope)'
flags: mi
---
[S4] when remaining slice hours exceed the time to the deadline, that turn says one Needs you line with the estimated finish date and the scope that can be cut.
