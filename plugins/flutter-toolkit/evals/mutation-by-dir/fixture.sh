#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# A repo (dart_mutants 0.7.0) on a branch `work` off `main` that changes one
# line in lib/core/db/store.dart and one in lib/ui/home/page.dart. test/ has
# test/core/db and test/ui, but no test/ui/home, so page.dart falls back to test/ui.
# fake/dart stands in for the engine: it appends its --test-command and --lines
# to calls.txt and reports one survivor a test reaches on each line it was asked about.
set -euo pipefail
g() { git -c user.name=e -c user.email=e@e "$@"; }
mkdir -p fake
cat > fake/dart <<'DART'
#!/usr/bin/env bash
cmd=""; lines=""; o=""
while [ $# -gt 0 ]; do
  case "$1" in
    --test-command) cmd=$2; shift ;;
    --lines) lines="$lines $2"; shift ;;
    --output) o=$2; shift ;;
  esac
  shift
done
echo "cmd=$cmd lines=${lines# }" >> "$EVAL_WS/calls.txt"
entries=""
for l in $lines; do
  f=${l%%:*}; n=${l#*:}; n=${n%%-*}
  s=$(printf '{"filePath":"%s","line":%s,"column":5,"operatorName":"relational_operator_replacement","description":"< → <=","uncovered":false}' "$f" "$n")
  entries="$entries${entries:+,}\"$f\":{\"filePath\":\"$f\",\"total\":2,\"detected\":1,\"undetected\":1,\"invalid\":0,\"timedOut\":0,\"undetectedMutants\":[$s]}"
done
printf '{"files":{%s}}' "$entries" > "$o"
exit 1
DART
chmod +x fake/dart
mkdir -p r/lib/core/db r/lib/ui/home r/test/core/db r/test/ui
cd r
printf 'name: app\ndev_dependencies:\n  dart_mutants:\n    git: x\n' > pubspec.yaml
printf 'packages:\n  dart_mutants:\n    dependency: "direct dev"\n    version: "0.7.0"\n' > pubspec.lock
printf 'int s1() => 1;\nint s2() => 2;\n' > lib/core/db/store.dart
printf 'int p1() => 1;\nint p2() => 2;\n' > lib/ui/home/page.dart
touch test/core/db/store_test.dart test/ui/page_test.dart
git init -q -b main && g add -A && g commit -qm base && git switch -qc work
printf 'int s1() => 1;\nint s2() => 20;\n' > lib/core/db/store.dart
printf 'int p1() => 10;\nint p2() => 2;\n' > lib/ui/home/page.dart
g commit -qam change
