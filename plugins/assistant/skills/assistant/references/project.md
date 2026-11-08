# Project config — what a project declares (in its own `.claude/assistant.md`)

One file per project; the flow is one, the differences live here. Missing entry →
the assistant asks once and writes it; a field not listed here is ignored. `asst-*` scripts key their state on the
directory holding this file (`.claude/.assistant/`, personal and unversioned).

```
vcs:        git | svn                      # git: worktree per task, one commit per slice, the commit hook runs the project's checks; svn: working copy per task, a saved diff per slice, the builder runs the project's checks, nothing committed before the delivery summary
board:      notion | file                  # where task rows live — the TaskList under notion_root, or .claude/.assistant/board.md; asst-board hides the difference
notion_root: <page-id>                     # board=notion: the KB root; TaskList / decision-log / KB Pages resolve by title under it
kb:         <dir>                          # board=file: the KB directory (e.g. docs/kb) — `asst-board decide` writes under <dir>/decisions/, and a KB module's pages under <dir>/<module>/
coverage:   <command, ci or none>          # line coverage on the diff; passes when every changed line executed, with no coverage-ignore comments; ci = the PR's CI measures it, so there is no verify-coverage report
render:     <command or none>              # writes one image per screen × state × locale into one directory, named <screen>-<state>-<locale>.png or <screen>__<state…>__<theme>__<locale>.png; asst-screens builds the screen-review page from them
analytics:  <gcp-project or none>          # the project the Firebase / GA4 BigQuery export lands in; asst-analytics reads it (references/analytics.md)
rules:      <path or none>                 # the project's rules, a file or a directory whose every .md is read — the project-rules layer under style-pack and ui-text-pack §Precedence. `style-pack --paths` prints them (a missing entry reads as none), skipping a file whose `paths:` frontmatter matches none of the paths
architecture: <path or none>               # the repo's architecture document, a file or a directory whose every .md is read; a missing entry is none, never asked. references/brief.md says how it binds
```
