#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# app/ is a Flutter package (`sdk: flutter`) whose change adds an enum file
# (lib/shade.dart, no executable line) and edits lib/count.dart. dart/ is a pure
# Dart package with the same change. fake/flutter stands in for `flutter test`:
# the suite's lcov records lib/count.dart only, and the import-only test's lcov records
# nothing, as a real run does for a declaration-only file. The import-only test also
# records in import-slot.txt whether the only test slot is held while it runs: held
# when an exclusive flock cannot be taken on slot-1 right now. fake/run-suite is a test
# command that starts with neither flutter nor dart.
set -euo pipefail
mkdir -p fake
cat > fake/flutter <<'F'
#!/usr/bin/env bash
out=coverage/lcov.info; prev=""
for a in "$@"; do [ "$prev" = --coverage-path ] && out=$a; prev=$a; done
mkdir -p "$(dirname "$out")"
case "$out" in
  coverage/lcov.info) printf 'SF:lib/count.dart\nDA:1,1\nend_of_record\n' > "$out" ;;
  *) : > "$out"
     s="$TEST_QUEUE_DIR/slot-1"
     if [ ! -e "$s" ]; then held=free
     elif perl -MFcntl=:flock -e 'open(my $f, "<", $ARGV[0]) or exit 2; exit(flock($f, LOCK_EX | LOCK_NB) ? 0 : 1)' "$s"; then held=free
     else held=held; fi
     echo "$held" > "$(dirname "$0")/../import-slot.txt" ;;
esac
F
chmod +x fake/flutter
printf '#!/usr/bin/env bash\nexec flutter test "$@"\n' > fake/run-suite
chmod +x fake/run-suite
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
