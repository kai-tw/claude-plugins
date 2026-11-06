# Project config — claude-plugins

```
vcs:        git
base_branch: none
board:      file
kb_pages:   none
kb:         .claude/.assistant/kb
check:      node .github/scripts/validate.mjs && node .github/scripts/run-evals.mjs --base main
coverage:   none
device_test: none
features:   none
render:     none
ui_strings: none
strings_glossary: none
strings_check: none
analytics:  none
cloud_fire: none
rules:      .claude/rules
destructive: force-push, deleting a remote branch, `gh pr merge`, uninstalling a plugin from a consumer project
```
