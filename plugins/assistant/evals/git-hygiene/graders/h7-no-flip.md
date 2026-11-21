---
type: regex
pattern: '^skills/assistant/SKILL\.md: .*((never|not|n.t|without|skips?|no need to) (first )?(read|reads|reading) (its|that repo.s) CLAUDE|(never|not|n.t) (send|sends|sending) (that session )?a patch|(edit|editing) it yourself[^;.]*(instead|rather)|(send|sending|sent)[^.]*without (asking|ask)|(never|not|n.t) (public|private))|^skills/assistant/references/cloud-dispatch\.md: .*(CLAUDE\.md|already working|its own rules)'
match: not_contains
flags: mi
---
[H7] The another-repo rule is never negated, and cloud-dispatch.md never restates it.
