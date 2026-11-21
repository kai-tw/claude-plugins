---
type: regex
pattern: '^skills/assistant/references/pr\.md: .*(5xx|server error).*githubstatus\.com.*(incident|outage)[^.]*user.*(not|never|no)[^.]*(retry|retries|retrying)[^.]*CronCreate'
flags: mi
---
[M3] pr.md: a 5xx from git push or gh, or "Merge already in progress", means read the githubstatus.com summary and name any incident to the user; never retry back to back, schedule one CronCreate retry.
