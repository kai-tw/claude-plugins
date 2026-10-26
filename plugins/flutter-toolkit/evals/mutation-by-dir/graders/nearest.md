---
type: regex
pattern: '^call: cmd=flutter test test/ui lines=lib/ui/home/page\.dart:1-1$'
flags: m
arm: with-only
---
With no test/ui/home, the file falls back to the nearest test directory that exists.
