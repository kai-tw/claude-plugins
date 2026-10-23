---
type: regex
pattern: 'forwarder failed:.*(Usage|--secret|--url)'
match: not_contains
---
The usage text is left out of the failure message.
