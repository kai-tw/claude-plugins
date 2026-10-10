---
type: regex
pattern: '^runner-args: --cloud\|Hello! You are the mutation runner\..*delaySeconds 3000 .*\|Run it\|--model\|sonnet\|--effort\|medium\|--name\|NG Assistant - solo · main\|--debug-file\|[^|]+\|$'
flags: m
arm: with-only
---
The mutation-runner profile passes sonnet / medium, its preamble first, the 50-minute wakeup rule, then the task, and the title prefixed with the launching session's name as --name.
