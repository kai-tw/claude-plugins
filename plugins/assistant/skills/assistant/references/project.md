# Project config — what a project declares (in its own `.claude/assistant.md`)

One file per project; the flow is one, the differences live here. Missing entry →
the assistant asks once and writes it; a field not listed here is ignored. `asst-*` scripts key their state on the
directory holding this file (`.claude/.assistant/`, personal and unversioned).

```
coverage:   <command, ci or none>          # line coverage on the diff; passes when every changed line executed, with no coverage-ignore comments; ci = the PR's CI measures it, so there is no verify-coverage report
render:     <command or none>              # writes one image per screen × state × locale into one directory, named <screen>-<state>-<locale>.png or <screen>__<state…>__<theme>__<locale>.png; asst-screens builds the screen-review page from them
analytics:  <gcp-project or none>          # the project the Firebase / GA4 BigQuery export lands in; asst-analytics reads it (references/analytics.md)
rules:      <path or none>                 # the project's rules, a file or a directory whose every .md is read — the project-rules layer under style-pack and ui-text-pack §Precedence. `style-pack --paths` prints them (a missing entry reads as none), skipping a file whose `paths:` frontmatter matches none of the paths
architecture: <path or none>               # the repo's architecture document, a file or a directory whose every .md is read; a missing entry is none, never asked. references/brief.md says how it binds
```
