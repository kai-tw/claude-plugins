#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# run.sh stands in for a plan-mutation run: it holds the marker for 3 s, then
# takes it away the way a run's cleanup does.
set -euo pipefail
git init -q
cat > run.sh <<'RUN'
printf 'pid: %s\n' $$ > .mutation-in-progress; sleep 3; mv .mutation-in-progress .ended
RUN
