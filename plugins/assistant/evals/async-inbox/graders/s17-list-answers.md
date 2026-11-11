---
type: regex
pattern: '^s17-list-answers=[1-9]'
flags: m
arm: with-only
---
[S17] While a question is up, every scheduler pass lists `answers`, so an answer whose wake failed is still acted on.
