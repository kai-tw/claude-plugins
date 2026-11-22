---
type: regex
pattern: '^(skills/assistant/SKILL\.md|skills/assistant/references/(tracker|brief)\.md|agents/builder\.md): .*(no deadline|without a deadline|has no deadline)[^.]*(skips?|(runs?|gets?|has|does) no|never (runs?|gets?|does))( the| this| its| a| any)? (late |deadline )?(check|compar)|(no deadline|without a deadline|has no deadline)[^.]*(check|compar)[^.]*(skipped|not run|never run)|(no deadline|without a deadline|has no deadline)[^.]*(is|are) (never|not) (checked|compared)'
flags: mi
---
[C4] a task with no deadline skips the late check.
