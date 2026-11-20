---
type: regex
pattern: '^s11-registered=yes$'
flags: m
arm: with-only
---
[S11] hooks.json registers hooks/checks/brief-chat.sh under PreToolUse in an entry with no matcher (or one matching every tool).
