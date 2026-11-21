---
type: regex
pattern: '^agents/advisor\.md: .*((^|\. |: |— )Before [^.]*(report|hand)[^.]*, (close|stop|kill|shut down) [^.]*(browser|server)|(^|\. |: |— )(Close|Stop|Kill|Shut down) [^.]*(browser|server)[^.]*before [^.]*(report|hand|return))'
flags: m
---
[D4] advisor.md: before it reports, the agent closes the browsers, servers and other processes it started itself.
