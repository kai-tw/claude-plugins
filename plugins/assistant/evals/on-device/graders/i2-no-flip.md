---
type: regex
pattern: '^skills/assistant/references/on-device\.md: .*((no need to|need not|don.t|do not|never|without) ask(ing)?[^.]*(user.s|own) (phone|device)|(user.s|own) (phone|device)[^.]*without ask|(never|not|won.t|doesn.t|cannot|can.t) (uninstall|remove|clear|wipe)|ask(ing)?[^.]*(user.s|own) (phone|device)[^.]*(unless|except|only if|when the user)|(unless|except|only if)[^.]*ask[^.]*(user.s|own) (phone|device))'
match: not_contains
flags: mi
---
[I2] Never runs on the user's own phone without asking, and never says a run leaves the app and its data alone.
