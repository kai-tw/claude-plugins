#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
set -euo pipefail
mkdir -p .claude/.assistant/tasks/t1
printf 'vcs: git\nboard: notion\nnotion_root: abcdefabcdefabcdefabcdefabcdefab\nkb_pages: product\ngate: dart test\n' > .claude/assistant.md
echo 11112222333344445555666677778888 > .claude/.assistant/tasks/t1/page
printf '# Pro tier\n\n### voice pick\n**Feature**: Read aloud、Human voice\n**Context** two voices\n**Decision** human voice\n**Consequence** synthetic dropped\n### quota\n**Feature** Read aloud\n**Context** c\n**Decision** d\n**Consequence** e\n### cache lib\n**Feature**: none\n**Context** c\n**Decision** d\n**Consequence** e\n' > decisions.md
printf '# Dark mode\n\n### palette\n**Context** c\n**Decision** d\n**Consequence** e\n' > nofeature.md
printf '# Pro tier\n\n## Overview\nx.\n' > archive.md
