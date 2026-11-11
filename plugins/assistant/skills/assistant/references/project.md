# Project config — what a project declares (in its own `.claude/assistant.md`)

One file per project; the flow is one, the differences live here. Missing entry →
the assistant asks once and writes it; a field not listed here is ignored. `asst-*` scripts key their state on the
directory holding this file (`.claude/.assistant/`, personal and unversioned).

```
rules:      <path or none>                 # the project's rules, a file or a directory whose every .md is read — the project-rules layer under style-pack §Precedence. `style-pack --paths` prints them (a missing entry reads as none), skipping a file whose `paths:` frontmatter matches none of the paths
architecture: <path or none>               # the repo's architecture document, a file or a directory whose every .md is read; a missing entry is none, never asked. references/brief.md says how it binds
```
