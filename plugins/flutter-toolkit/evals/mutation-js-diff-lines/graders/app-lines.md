---
type: regex
pattern: '^args: app: run --mutate lib/m\.ts:2-2 --reporters'
flags: m
arm: with-only
---
app/ gets m.ts's changed line; its ESM config excludes skip.ts.
