# Project adapter — what a project declares (in its own `.claude/assistant.md`)

One file per project; the flow is one, the differences live here. Missing entry →
the assistant asks once and writes it. `asst-*` scripts key their state on the
directory holding this file (`.claude/.assistant/`, personal and unversioned).

```
vcs:        git | svn                      # git: worktree per task, checkpoint = commit, hook runs `gate`; svn: working copy per task, checkpoint = saved diff, builder runs `gate`, nothing committed before ③
board:      notion | file                  # where task rows live — the TaskList under notion_root, or .claude/.assistant/board.md; asst-board hides the difference
notion_root: <page-id>                     # board=notion: the KB root; TaskList / feature-archive / decision-log resolve by title under it
kb:         <dir>                          # board=file: where `asst-board archive` lands (e.g. docs/decisions)
gate:       <command>                      # lint · format · tests in one command; red blocks the checkpoint
coverage:   <command or none>              # per-line reach on the diff; gate: every changed line executed, no exemptions
mutation:   <command or none>              # mutation score on the diff; gate: ≥ 80
render:     <command or none>              # produces the contact sheet for ② screens and strings
ui_strings: <glob or none>                 # where the user-visible strings live (ARB); none = this project has none yet, the text leg is skipped
locales:    <source> [→ <targets…>]       # ui_strings non-none: the source locale and every locale a key must carry
strings_canon: <path or none>             # the project's own string canon when it sits outside rules: (the regulation layer under ui-text-pack §Precedence)
strings_check: <command or none>          # the project's mechanical string checks (term blocklist, sort, duplicates); red blocks ③
cloud_fire: <url or none>                  # the routine's /fire endpoint, for opening a cloud session from a non-interactive shell; the token is read only from an environment variable
rules:      <path>                         # the project's .claude/rules/ — the regulation layer under style-pack §Precedence; the verifier grades against both
destructive: <list>                        # actions the assistant must ask before (svn commit / revert, force-push, …)
```
