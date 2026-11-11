---
type: regex
pattern: '^error-trash: exit=[1-9] writes=0 msg='
flags: m
arm: with-only
---
trash is stopped, with nothing sent, when the page lookup answers with a Notion error object.
