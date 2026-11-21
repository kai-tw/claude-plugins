---
type: regex
pattern: '^index\.md: - \*\*S4\.[0-9]+ .*atomic.*(partial|half[- ]written|torn|incomplete|truncated|partly written)[^.]*violat|^index\.md: - \*\*S4\.[0-9]+ .*(partial|half[- ]written|torn|incomplete|truncated|partly written)[^.]*violat.*atomic'
flags: mi
arm: with-only
---
[J9] S4: a persisted write that can leave half-written data violates the rule; the write is atomic.
