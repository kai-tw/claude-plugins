#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# Two repos on a branch `work` off `main` that changed lines 2-3 of lib/a.dart.
# fake/dart stands in for the engine and answers by the repo's directory name.
# In r/ two mutants survive: line 2 reached by a test, line 3 by none. In eq/
# the only leftovers are an equivalent survivor (a switch arm replaced with
# the same text) and a timed-out mutant.
set -euo pipefail
g() { git -c user.name=e -c user.email=e@e "$@"; }
mkdir -p fake
cat > fake/dart <<'DART'
#!/usr/bin/env bash
while [ $# -gt 0 ]; do [ "$1" = --output ] && o=$2; shift; done
m() { printf '{"filePath":"lib/a.dart","line":%s,"column":5,"operatorName":"%s","description":"%s","uncovered":%s}' "$@"; }
if [ "$(basename "$PWD")" = eq ]; then
  printf '{"files":{"lib/a.dart":{"filePath":"lib/a.dart","total":6,"detected":4,"undetected":1,"invalid":0,"timedOut":1,"undetectedMutants":[%s],"timedOutMutants":[%s]}}}' \
    "$(m 2 switch_expression_arm_swap "switch arm result 'Kind.a' replaced with 'Kind.a'" false)" \
    "$(m 3 relational_operator_replacement "< → <=" false)" > "$o"
else
  printf '{"files":{"lib/a.dart":{"filePath":"lib/a.dart","total":6,"detected":4,"undetected":2,"invalid":0,"timedOut":0,"undetectedMutants":[%s,%s]}}}' \
    "$(m 2 relational_operator_replacement "< → <=" false)" \
    "$(m 3 relational_operator_replacement "< → <=" true)" > "$o"
fi
exit 1
DART
chmod +x fake/dart
for p in r eq; do
  mkdir -p "$p/lib"
  printf 'name: app\ndev_dependencies:\n  dart_mutants:\n    git: x\n' > "$p/pubspec.yaml"
  printf 'packages:\n  dart_mutants:\n    dependency: "direct dev"\n    version: "0.7.0"\n' > "$p/pubspec.lock"
  printf 'int a1() => 1;\nint a2() => 2;\nint a3() => 3;\n' > "$p/lib/a.dart"
  (cd "$p" && git init -q -b main && g add -A && g commit -qm base && git switch -qc work)
  printf 'int a1() => 1;\nint a2() => 20;\nint a3() => 30;\n' > "$p/lib/a.dart"
  (cd "$p" && g commit -qam change)
done
