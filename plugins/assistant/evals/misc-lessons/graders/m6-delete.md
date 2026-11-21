---
type: regex
pattern: '^skills/assistant/references/tracker\.md: .*(subject|topic)[^.]*(gone|no longer exist|removed)[^.]*(source|code|CI)[^.]*(delete|remove)[^.]*(without asking|no ask|not ask|never ask|don.t ask)|^skills/assistant/references/tracker\.md: .*(delete|remove)[^.]*(without asking|don.t ask)[^.]*(subject|topic)[^.]*(gone|no longer exist|removed)'
flags: mi
---
[M6] tracker.md scheduler pass: a row whose subject is gone (code removed, reported failure vanished) is deleted without asking once source or CI confirms it, and the answer says what was checked.
