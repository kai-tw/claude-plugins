---
type: regex
pattern: '^args: web: run --mutate src/a\.ts:3-4,src/a\.ts:8-8,src/b\.ts:1-3 --reporters'
flags: m
arm: with-only
---
web/ gets only the changed lines of a.ts and b.ts; c.ts only lost a line, and its JSON config excludes index.js.
