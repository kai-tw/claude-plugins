---
type: regex
pattern: '^skills/assistant/references/on-device\.md: .*((may|is fine to|is allowed to|is ok(ay)? to|can) (trigger|fire|send|make|complete|run)( a| any)?( real)? (paid|purchase|billed)|(paid|purchase)[^.]*(allowed|fine|ok(ay)?) (when|if|with|once)|paid (request|call|api)[^.]*(unless|except|only if|when the user))'
match: not_contains
flags: mi
---
[I6] A paid request or real purchase is never allowed.
