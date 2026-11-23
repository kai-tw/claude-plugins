---
type: regex
pattern: '^skills/assistant/SKILL\.md: .*(2nd|second) brief version filed after the first .?build-\*.? report([^.]|\.[^ ])*(stop dispatch|Needs you)'
flags: mi
match: not_contains
---
[D4] SKILL.md: the stop rule no longer stops dispatch or asks the user with `Needs you`.
