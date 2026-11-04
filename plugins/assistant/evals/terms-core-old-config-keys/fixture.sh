#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# A project whose config predates check: and strings_glossary:.
set -euo pipefail
mkdir -p .claude
printf 'vcs: svn\nboard: file\nkb: docs/kb\ngate: npm test\nstrings_canon: docs/glossary.md\n' > .claude/assistant.md
