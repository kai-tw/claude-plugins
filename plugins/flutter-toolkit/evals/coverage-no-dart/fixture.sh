#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# A repo whose branch `ci` changes only a workflow file; lib/a.dart is untouched.
# fake_test.sh stands in for `flutter test` and leaves a marker file when it runs.
set -euo pipefail
g() { git -c user.name=e -c user.email=e@e "$@"; }
printf 'echo ran > "$(dirname "$0")/ran"\n' > fake_test.sh
mkdir -p r/lib r/.github/workflows
cd r
printf 'int a() => 1;\n' > lib/a.dart
printf 'name: ci\n' > .github/workflows/pr-checks.yml
git init -q -b main && g add -A && g commit -qm base
git switch -qc ci; printf 'name: ci\non: pull_request\n' > .github/workflows/pr-checks.yml; g commit -qam ci
