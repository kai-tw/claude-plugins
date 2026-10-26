#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# A repo with two branches off `main`: `ci` changes only a workflow file, `code`
# changes lib/a.dart.
set -euo pipefail
g() { git -c user.name=e -c user.email=e@e "$@"; }
mkdir -p r/lib r/.github/workflows
cd r
printf 'int a() => 1;\n' > lib/a.dart
printf 'name: ci\n' > .github/workflows/pr-checks.yml
git init -q -b main && g add -A && g commit -qm base
git switch -qc ci; printf 'name: ci\non: pull_request\n' > .github/workflows/pr-checks.yml; g commit -qam ci
git switch -q main; git switch -qc code; printf 'int a() => 2;\n' > lib/a.dart; g commit -qam code
