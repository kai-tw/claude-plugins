#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# r/ is a repo on branch `work` off `main` that changed lib/a.dart. fake/dart
# stands in for the engine: 6 mutants, 4 detected, 2 survivors a test reaches —
# line 3 swaps a switch arm for an arm with the same result (equivalent), line 4
# for an arm with a different one (a real survivor). Scored with the equivalent
# the file is 66% (FAIL); without it, 80% (PASS).
set -euo pipefail
g() { git -c user.name=e -c user.email=e@e "$@"; }
mkdir -p fake r/lib
cat > fake/dart <<'DART'
#!/usr/bin/env bash
while [ $# -gt 0 ]; do [ "$1" = --output ] && o=$2; shift; done
s() { printf '{"filePath":"lib/a.dart","line":%s,"column":5,"operatorName":"switch_expression_arm_swap","description":"switch arm result %s replaced with %s","uncovered":false}' "$1" "'$2'" "'$3'"; }
printf '{"files":{"lib/a.dart":{"filePath":"lib/a.dart","total":6,"detected":4,"undetected":2,"invalid":0,"timedOut":0,"undetectedMutants":[%s,%s]}}}' \
  "$(s 3 Kind.a Kind.a)" "$(s 4 Kind.a Kind.b)" > "$o"
exit 1
DART
chmod +x fake/dart
cd r
printf 'name: app\ndev_dependencies:\n  dart_mutants:\n    git: x\n' > pubspec.yaml
printf 'packages:\n  dart_mutants:\n    dependency: "direct dev"\n    version: "0.7.0"\n' > pubspec.lock
printf 'int f(int x) => switch (x) {\n  0 => 1,\n  1 => 1,\n  _ => 2,\n};\n' > lib/a.dart
git init -q -b main && g add -A && g commit -qm base && git switch -qc work
printf 'int f(int x) => switch (x) {\n  0 => 1,\n  1 => 1,\n  _ => 3,\n};\n' > lib/a.dart
g commit -qam change
