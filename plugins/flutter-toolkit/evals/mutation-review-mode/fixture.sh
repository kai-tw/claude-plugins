#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# Two repos on a branch `work` off `main`. In r/ (dart_mutants 0.7.0) the
# branch changes lines 2-3 of lib/a.dart and only deletes a line of
# lib/b.dart. old/ resolves 0.6.1.
# fake/dart stands in for the engine: it records its arguments and writes a
# report with two survivors in lib/a.dart — line 2 reached by a test, line 3
# reached by none.
set -euo pipefail
g() { git -c user.name=e -c user.email=e@e "$@"; }
mkdir -p fake
cat > fake/dart <<'DART'
#!/usr/bin/env bash
echo "$*" > args.txt
while [ $# -gt 0 ]; do [ "$1" = --output ] && o=$2; shift; done
s() { printf '{"filePath":"lib/a.dart","line":%s,"column":5,"operatorName":"relational_operator_replacement","description":"< → <=","uncovered":%s}' "$1" "$2"; }
printf '{"files":{"lib/a.dart":{"filePath":"lib/a.dart","total":3,"detected":1,"undetected":2,"invalid":0,"timedOut":0,"undetectedMutants":[%s,%s]}}}' "$(s 2 false)" "$(s 3 true)" > "$o"
exit 1
DART
chmod +x fake/dart
for p in r old; do
  mkdir -p "$p/lib"
  v=0.7.0; [ $p = old ] && v=0.6.1
  printf 'name: app\ndev_dependencies:\n  dart_mutants:\n    git: x\n' > "$p/pubspec.yaml"
  printf 'packages:\n  dart_mutants:\n    dependency: "direct dev"\n    version: "%s"\n' "$v" > "$p/pubspec.lock"
  printf 'int a1() => 1;\nint a2() => 2;\nint a3() => 3;\nint a4() => 4;\n' > "$p/lib/a.dart"
  printf 'int b1() => 1;\nint b2() => 2;\n' > "$p/lib/b.dart"
  (cd "$p" && git init -q -b main && g add -A && g commit -qm base && git switch -qc work \
    && printf 'args.txt\n' >> .git/info/exclude)
  printf 'int a1() => 1;\nint a2() => 20;\nint a3() => 30;\nint a4() => 4;\n' > "$p/lib/a.dart"
  printf 'int b1() => 1;\n' > "$p/lib/b.dart"
  (cd "$p" && g commit -qam change)
done
