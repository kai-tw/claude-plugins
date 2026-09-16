# Project adapter — what a project declares (in its own `.claude/assistant.md`)

One file per project; the flow is one, the differences live here. Missing entry →
the assistant asks once and writes it.

```
vcs:        git | svn                      # worktree vs working copy; push vs commit-to-branch
notion_root: <page-id>                     # the KB root; TaskList is resolved by title under it
lint:       <command>                      # commit-hook leg
test:       <command>
coverage:   <command or none>              # per-line reach on the diff; gate: every changed line executed, no exemptions
mutation:   <command or none>              # mutation score on the diff; gate: ≥ 80
render:     <command or none>              # produces the contact sheet for ② 畫面
rules:      <path>                         # the project's .claude/rules/ — 命令層 under style-pack §位階; the verifier grades against both
destructive: <list>                        # actions the assistant must ask before (svn revert, force-push, …)
```
