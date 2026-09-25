#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# engine/ stands in for kai-packages with tags up to 0.5.1. Three projects on
# the floor (0.5.0): a Flutter one and a Dart one, each one release behind, and
# a Flutter one whose "latest" is its own version (engine-same/ tops out at 0.5.0).
# fake/dart stands in for the engine: it writes a passing report for lib/a.dart.
set -euo pipefail
g() { git -c user.name=e -c user.email=e@e "$@"; }
mkrepo() { mkdir -p "$1" && (cd "$1" && git init -q && touch .keep && git add -A && g commit -qm init); }
mkrepo engine; for v in 0.4.0 0.5.0 0.5.1; do git -C engine tag "dart_mutants-v$v"; done
mkrepo engine-same; git -C engine-same tag dart_mutants-v0.5.0
mkdir -p fake
cat > fake/dart <<'DART'
#!/usr/bin/env bash
while [ $# -gt 0 ]; do [ "$1" = --output ] && o=$2; shift; done
printf '{"files":{"lib/a.dart":{"filePath":"lib/a.dart","total":5,"detected":5,"invalid":0,"timedOut":0}}}' > "$o"
DART
chmod +x fake/dart
lock='packages:\n  dart_mutants:\n    dependency: "direct dev"\n    version: "0.5.0"\n'
for p in flutter dart same; do
  mkdir -p "$p/lib"
  case $p in
    dart) printf 'name: app\ndev_dependencies:\n  dart_mutants:\n    git: x\n' > "$p/pubspec.yaml" ;;
    *)    printf 'name: app\ndependencies:\n  flutter:\n    sdk: flutter\ndev_dependencies:\n  dart_mutants:\n    git: x\n' > "$p/pubspec.yaml" ;;
  esac
  printf "$lock" > "$p/pubspec.lock"
  printf 'int a() => 1;\n' > "$p/lib/a.dart"
  (cd "$p" && git init -q && git add -A && g commit -qm init)
done
