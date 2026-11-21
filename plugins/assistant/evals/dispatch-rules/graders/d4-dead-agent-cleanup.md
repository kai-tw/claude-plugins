---
type: regex
pattern: '^skills/assistant/SKILL\.md: .*(agent (dies|died|is dead|has died)[^.]*, (you )?(close|kill|stop|clean up|shut down) [^.]*(process|browser|server)|(Close|Kill|Stop|Clean up|Shut down) [^.]*(process|browser|server)[^.]*(dead|died))'
flags: m
---
[D4] SKILL.md: when an agent dies, the assistant cleans up the processes it left behind.
