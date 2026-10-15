---
type: regex
pattern: '--files lib/gone\.dart|issue create mutation [A-Z]+: lib/gone'
flags: m
match: not_contains
---
A skipped file is neither run nor reported.
