---
type: regex
pattern: '^bad-pgrep-[a-z]+=miss'
flags: m
match: not_contains
arm: with-only
---
[D5] Every `while`/`until` `pgrep -f` loop is flagged: with or without redirected output, with `until ! pgrep -fl`, unquoted, and with `do` on the next line.
