---
type: regex
pattern: '^skills/assistant/SKILL.md: (before|prior to)[^.]*(creat|provision)[^.]*(cloud|billed|paid)[^.]*(price|pricing|cost)[^.]*(free|cheapest)[^.]*(monthly)[^.]*(cost|fee|price|estimate)'
flags: mi
---
[M4] SKILL.md Dispatch rules: look up the price before creating a billed cloud resource, take the free or cheapest tier that fits, report the estimated monthly cost (or say none was found).
