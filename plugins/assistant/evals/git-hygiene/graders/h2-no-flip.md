---
type: regex
pattern: '\*\*ui\*\*[^*]*((no|never|not|n.t|without)( a| one| any)? commit|commit(s|ting)? (nothing|later|in integration))[^*]*\*\*integration\*\*'
match: not_contains
flags: mi
---
[H2] The ui phase is never told to leave its work uncommitted.
