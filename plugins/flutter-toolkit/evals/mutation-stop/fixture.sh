#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# A repo, new/, with lib/a.dart resolving dart_mutants 0.5.0. fake/dart stands
# in for the engine: it records its arguments, then runs until SIGTERM and exits
# the way a signalled engine does, writing no report.
set -euo pipefail
g() { git -c user.name=e -c user.email=e@e "$@"; }
mkdir -p fake
cat > fake/dart <<'DART'
#!/usr/bin/env bash
echo "$*" > args.txt
trap 'exit 143' TERM
sleep 30 & wait $!
DART
chmod +x fake/dart
for p in new; do
  mkdir -p "$p/lib"
  printf 'name: app\ndev_dependencies:\n  dart_mutants:\n    git: x\n' > "$p/pubspec.yaml"
  printf 'packages:\n  dart_mutants:\n    dependency: "direct dev"\n    version: "0.5.0"\n' > "$p/pubspec.lock"
  printf 'int a() => 1;\n' > "$p/lib/a.dart"
  (cd "$p" && git init -q && g add -A && g commit -qm init && printf 'args.txt\nrun.log\n' >> .git/info/exclude)
done
