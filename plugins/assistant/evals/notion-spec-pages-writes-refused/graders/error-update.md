---
type: regex
pattern: '^error-update: exit=[1-9] writes=0 msg='
flags: m
arm: with-only
---
update is stopped, with nothing sent, when the page lookup answers with a Notion error object.
