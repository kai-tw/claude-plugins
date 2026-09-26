---
type: regex
pattern: 'commit message: #346 is no issue or PR of acme/lib'
flags: m
arm: with-only
---
A bare issue number that is not this repo's is refused; #1, which exists, is not.
