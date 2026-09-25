#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# A project whose pubspec.lock resolves dart_mutants 0.4.0 — the last release without a journal.
set -euo pipefail
git init -q
mkdir -p lib && printf 'int a() => 1;\n' > lib/a.dart
printf 'name: app\ndev_dependencies:\n  dart_mutants:\n    git: x\n' > pubspec.yaml
printf 'packages:\n  dart_mutants:\n    dependency: "direct dev"\n    version: "0.4.0"\n' > pubspec.lock
git add -A && git -c user.name=e -c user.email=e@e commit -qm init
