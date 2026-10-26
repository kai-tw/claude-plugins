#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# app/ is a Flutter package (`sdk: flutter`) whose change adds an enum file
# (lib/shade.dart, no executable line) and edits lib/count.dart. dart/ is a pure
# Dart package with the same change. fake/flutter stands in for `flutter test`:
# the suite's lcov records lib/count.dart only, and the probe's lcov records
# nothing, as a real run does for a declaration-only file.
set -euo pipefail
mkdir -p fake
cat > fake/flutter <<'F'
#!/usr/bin/env bash
out=coverage/lcov.info; prev=""
for a in "$@"; do [ "$prev" = --coverage-path ] && out=$a; prev=$a; done
mkdir -p "$(dirname "$out")"
case "$out" in
  coverage/lcov.info) printf 'SF:lib/count.dart\nDA:1,1\nend_of_record\n' > "$out" ;;
  *) : > "$out" ;;
esac
F
chmod +x fake/flutter
for p in app dart; do
  mkdir -p "$p/lib" "$p/test"
  if [ $p = app ]; then
    printf 'name: app\ndependencies:\n  flutter:\n    sdk: flutter\n' > "$p/pubspec.yaml"
  else
    printf 'name: app\n' > "$p/pubspec.yaml"
  fi
  printf 'int count() => 1;\n' > "$p/lib/count.dart"
  (cd "$p" && git init -q -b main && git -c user.name=e -c user.email=e@e add -A && git -c user.name=e -c user.email=e@e commit -qm base && git switch -qc work)
  printf 'enum Shade { light, dark }\n' > "$p/lib/shade.dart"
  printf 'int count() => 2;\n' > "$p/lib/count.dart"
  (cd "$p" && git -c user.name=e -c user.email=e@e add -A && git -c user.name=e -c user.email=e@e commit -qm change)
done
printf 'mkdir -p coverage; printf "SF:lib/count.dart\\nDA:1,1\\nend_of_record\\n" > coverage/lcov.info\n' > dart/fake_test.sh
