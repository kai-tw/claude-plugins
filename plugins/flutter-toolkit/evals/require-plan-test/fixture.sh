#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
set -euo pipefail
git init -q
printf '%s\n' '{"tool_input":{"command":"cd x && flutter test -j 2 test/a/"}}' > bare.json
printf '%s\n' '{"tool_input":{"command":"echo run flutter test; plan-test test/a/"}}' > mention.json
