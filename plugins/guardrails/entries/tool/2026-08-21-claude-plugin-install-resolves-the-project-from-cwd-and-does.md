---
category: tool
source: founder
date: 2026-08-21
title: claude plugin install resolves the project from cwd and does not name it back
---

`--scope project` names the LEVEL, not which project — the target is resolved
from the working directory, and there is no argument to state it.

`install` confirms with `(scope: project)` and no path. `update` confirms with
the full path. So the one field that could reveal a wrong target is missing from
exactly the command that has no other check.

2026-08-21, twice in one session: a `cd` earlier in the same Bash string sent
`plan-cycle@kai-tw` into the `claude-plugins` repo, and sent a `plan-cycle`
uninstall at CherishCRM when it was meant for NovelGlide. Both printed
"✔ Successfully". Only listing every install afterwards surfaced it.

Pattern candidate: a command string carrying both `cd` and
`claude plugin (install|uninstall)`.
