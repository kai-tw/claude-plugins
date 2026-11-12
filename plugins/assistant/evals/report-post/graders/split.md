---
type: regex
pattern: '^split=[1-9]'
flags: m
arm: with-only
---
A private repo gets the full report; any other gets only the header and the note "Filed, not posted: this repo is not known to be private.", never report content.
