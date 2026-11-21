---
type: regex
pattern: 'own (changes|edits)[^.;]*approved[^.;]*(is not exempt|needs? asking|needs? to be asked|is asked first|are asked first|must be asked|requires? asking|ask first)'
match: not_contains
flags: m
---
[E9] SKILL.md: reverting your own changes to what the user approved is not turned back into an asked-first case.
