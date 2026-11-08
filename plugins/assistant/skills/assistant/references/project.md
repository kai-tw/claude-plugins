# Project config — what a project declares (in its own `.claude/assistant.md`)

One file per project; the flow is one, the differences live here. Missing entry →
the assistant asks once and writes it. `asst-*` scripts key their state on the
directory holding this file (`.claude/.assistant/`, personal and unversioned).

```
vcs:        git | svn                      # git: worktree per task, one commit per slice, hook runs `check`; svn: working copy per task, a saved diff per slice, builder runs `check`, nothing committed before the delivery summary
base_branch: <branch or none>             # git: the branch task branches start from and task PRs go into (e.g. staging, deployed to a test environment); none = the default branch. Production gets it by a release (references/release.md)
board:      notion | file                  # where task rows live — the TaskList under notion_root, or .claude/.assistant/board.md; asst-board hides the difference
notion_root: <page-id>                     # board=notion: the KB root; TaskList / decision-log / KB Pages resolve by title under it
kb_pages:   <modules> or none                # the KB modules this project keeps, picked from frontend · backend · product · marketing · design (SKILL.md §KB modules); none = no KB pages
kb:         <dir>                          # board=file: the KB directory (e.g. docs/kb) — `asst-board decide` writes under <dir>/decisions/, and each kb_pages module's pages under <dir>/<module>/
check:      <command>                      # lint · format · tests in one command; failing blocks the commit
coverage:   <command, ci or none>          # line coverage on the diff; passes when every changed line executed, with no coverage-ignore comments; ci = the PR's CI measures it, so there is no verify-coverage report
device_test: <command or none>            # runs the on-device suite on one phone, `{device}` = its id from `flutter devices`; asst-device runs it per platform and files verify-device
devices:    android ios                    # device_test non-none: the platforms whose phone must pass (both by default)
device_tests: <dir>                        # where the tester puts on-device tests (e.g. integration_test/)
features:   <path or none>                 # the app's feature list, `- <feature> · <on-device test file | none — why>`; the tester adds to it
render:     <command or none>              # writes one image per screen × state × locale into one directory, named <screen>-<state>-<locale>.png or <screen>__<state…>__<theme>__<locale>.png; asst-screens builds the screen-review page from them
ui_strings: <glob or none>                 # where the user-visible strings live (ARB); none = this project has none yet, the text review is skipped
locales:    <source> [→ <targets…>]       # ui_strings non-none: the source locale and every locale a key must carry
strings_glossary: <path or none>          # the project's own string glossary when it sits outside rules: (the project-rules layer under ui-text-pack §Precedence)
strings_check: <command or none>          # the project's mechanical string checks (term blocklist, sort, duplicates); failing blocks the delivery summary
analytics:  <gcp-project or none>          # the project the Firebase / GA4 BigQuery export lands in; asst-analytics reads it (references/analytics.md)
cloud_fire: <url or none>                  # the routine's /fire endpoint, for when asst-cloud cannot open a cloud session; the token is read only from an environment variable
rules:      <path or none>                 # the project's rules, a file or a directory whose every .md is read — the project-rules layer under style-pack §Precedence. `style-pack --paths` prints them (a missing entry reads as none), skipping a file whose `paths:` frontmatter matches none of the paths
architecture: <path or none>               # the repo's architecture document, a file or a directory whose every .md is read; a missing entry is none, never asked. references/brief.md says how it binds
destructive: <list>                        # actions the assistant must ask before (svn commit / revert, force-push, …)
```

Older configs: `gate:` is read as `check:` and `strings_canon:` as `strings_glossary:`; leave the file as it is.
