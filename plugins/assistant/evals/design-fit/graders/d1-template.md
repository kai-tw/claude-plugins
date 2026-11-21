---
type: regex
pattern: '^skills/assistant/references/brief\.md: .*((Fit: <[^>]*(criteria[^>]*evidence|evidence[^>]*criteria)[^>]*>.*Rejected alternatives: <[^>]*(criterion[^>]*evidence|evidence[^>]*criterion)[^>]*>)|(Rejected alternatives: <[^>]*(criterion[^>]*evidence|evidence[^>]*criterion)[^>]*>.*Fit: <[^>]*(criteria[^>]*evidence|evidence[^>]*criteria)[^>]*>))'
flags: mi
---
[D1] brief.md: the System design template has a Fit line and a Rejected alternatives line naming criterion and evidence, in either order.
