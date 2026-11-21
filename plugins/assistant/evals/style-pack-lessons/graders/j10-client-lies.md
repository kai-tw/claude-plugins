---
type: regex
pattern: '^index\.md: - \*\*S1[16]\.[0-9]+ .*(recovery|restore|repair|reconcil)[^.]*(client (may|can|might|will|could) lie|assum[a-z]* the client (lies|is lying|may lie|can lie)|trust(s|ing)? (what )?the client[^.]*violat)'
flags: mi
arm: with-only
---
[J10] S11 or S16: a recovery flow assumes the client may lie.
