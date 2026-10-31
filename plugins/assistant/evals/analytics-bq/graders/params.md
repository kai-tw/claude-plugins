---
type: regex
pattern: '^query .*UNNEST\(event_params\).*WHERE event_name = .book_open. AND'
flags: m
arm: with-only
---
params reads one event's parameters.
