# Project adapter — what a project declares (in its own `.claude/assistant.md`)

One file per project; the flow is one, the differences live here. Missing entry →
the assistant asks once and writes it. `asst-*` scripts key their state on the
directory holding this file (`.claude/.assistant/`, personal and unversioned).
`style-rules/*.md` under it: personal style rules, loaded by `style-pack`.

```
vcs:        git | svn                      # git: worktree per task, checkpoint = commit, hook runs `gate`; svn: working copy per task, checkpoint = saved diff, builder runs `gate`, nothing committed before ③
board:      notion | file                  # where task rows live — the TaskList under notion_root, or .claude/.assistant/board.md; asst-board hides the difference
notion_root: <page-id>                     # board=notion: the KB root; TaskList / decision-log resolve by title under it
kb_pages:   <modules> or none                # the KB modules this project keeps, picked from frontend · backend · product · marketing · design (SKILL.md §KB modules); none = no KB pages
kb:         <dir>                          # board=file: the KB directory (e.g. docs/kb) — `asst-board decide` writes under <dir>/decisions/, and each kb_pages module's pages under <dir>/<module>/
gate:       <command>                      # lint · format · tests in one command; red blocks the checkpoint
coverage:   <command, ci or none>          # per-line reach on the diff; gate: every changed line executed, no markers; ci = the PR's CI measures it, so there is no verify-coverage leg
device_test: <command or none>            # runs the on-device suite on one phone, `{device}` = its id from `flutter devices`; asst-device runs it per platform and files verify-device
devices:    android ios                    # device_test non-none: the platforms whose phone must pass (both by default)
device_tests: <dir>                        # where the tester puts on-device tests (e.g. integration_test/)
features:   <path or none>                 # the app's feature list, `- <feature> · <on-device test file | none — why>`; the tester adds to it
render:     <command or none>              # writes one image per screen × state × locale into one directory, named <screen>-<state>-<locale>.png or <screen>__<state…>__<theme>__<locale>.png; asst-screens builds the ② page from them
ui_strings: <glob or none>                 # where the user-visible strings live (ARB); none = this project has none yet, the text leg is skipped
locales:    <source> [→ <targets…>]       # ui_strings non-none: the source locale and every locale a key must carry
strings_canon: <path or none>             # the project's own string canon when it sits outside rules: (the regulation layer under ui-text-pack §Precedence)
strings_check: <command or none>          # the project's mechanical string checks (term blocklist, sort, duplicates); red blocks ③
cloud_fire: <url or none>                  # the routine's /fire endpoint, for when asst-cloud cannot open a cloud session; the token is read only from an environment variable
rules:      <path>                         # the project's .claude/rules/ — the regulation layer under style-pack §Precedence; the verifier grades against both
destructive: <list>                        # actions the assistant must ask before (svn commit / revert, force-push, …)
```
