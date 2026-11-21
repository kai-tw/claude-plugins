---
type: regex
pattern: '^skills/assistant/references/pr\.md: .*(5xx|server error).*githubstatus\.com.*(not|never|no).*(retry|retries|retrying).*CronCreate'
flags: mi
---
[M3] pr.md: a 5xx from git push or gh, or "Merge already in progress", means check githubstatus.com, no back-to-back retries, one CronCreate retry.
