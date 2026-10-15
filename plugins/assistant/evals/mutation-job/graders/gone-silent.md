---
type: regex
pattern: 'lib/gone\.dart -- flutter test|issue create mutation [A-Z]+: lib/gone'
flags: m
match: not_contains
---
A dropped file is neither run nor reported.
