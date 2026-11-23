---
type: regex
pattern: '^skills/assistant/SKILL\.md: .*(third|3rd) (design )?version([^.]|\.md)*(stop dispatch|Needs you)'
flags: mi
match: not_contains
---
[D4] SKILL.md: the stop rule no longer stops dispatch or asks the user with `Needs you`.
