---
type: regex
pattern: '^skills/assistant/references/brief\.md: .*deploy[^.]*((adds?|moves?)[^.]*(identity|environment variables?|regions?)|(identity|environment variables?|regions?)[^.]*(adds?|moves?))[^.]*cit(e|es|ing)[^.]*file:line[^.]*deploy(ment)?[^.]*sets? it'
flags: mi
---
[G2] brief.md: a deploy-time value the task adds or moves (the identity it runs as, an environment variable, a region) cites the file:line where the deploy sets it.
