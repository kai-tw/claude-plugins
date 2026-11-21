---
type: regex
pattern: '^agents/tester\.md: .*(request|error list|response|persisted)[^.]*(request|error list|response|persisted)[^.]*grep[^.]*(existing|other) tests'
flags: m
---
[A3] When the brief changes a convention (request shape, error list, response, persisted format), the tester greps the existing tests.
