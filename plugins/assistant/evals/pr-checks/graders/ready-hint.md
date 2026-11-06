---
type: regex
pattern: 'next: wait for the user to say the PR can merge'
arm: with-only
---
Turning a PR ready says the next step waits for the user.
---
type: regex
pattern: 'next: schedule .asst-pr checks x wt. to run once in 5 minutes \(CronCreate, recurring: false\), then end the turn'
flags: m
arm: with-only
---
ready names the one look at CI to schedule, never a wait.
