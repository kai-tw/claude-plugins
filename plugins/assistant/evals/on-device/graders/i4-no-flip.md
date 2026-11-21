---
type: regex
pattern: '^skills/assistant/references/on-device\.md: .*((no need to|need not|don.t|do not|never|skip|without) (restor|revert|put back|undo)|restor[a-z]*[^.]*(is|are) optional|exit (code|status)[^.]*(is|are) enough|exit (code|status) (alone )?suffices)'
match: not_contains
flags: mi
---
[I4] Restoring is never optional, and the exit code is never enough.
