---
type: regex
pattern: '^runner-args: --cloud\|Hello! You are the mutation runner\..*delaySeconds 3000 .*\|Run it\|--model\|sonnet\|--effort\|medium\|$'
flags: m
arm: with-only
---
The mutation-runner profile passes sonnet / medium, its preamble first, the 50-minute wakeup rule, then the task.
