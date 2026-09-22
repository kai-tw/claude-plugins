#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# fake_test.sh stands in for `flutter test`: it echoes the arguments it was
# given and writes the lcov a real branch-coverage run produces for lib/.
set -euo pipefail
git init -q
mkdir -p lib
cat > lib/a.dart <<'D'
class E implements Exception { const E(); }
int a(int x) {
  if (x < 0) {
    throw const E();
  }
  return x;
}
D
cat > lib/b.dart <<'D'
import 'a.dart';
int b(int? x) => x ?? (throw const E());
D
cat > lib/c.dart <<'D'
int c(int x) {
  if (x < 0) {
    return -x;
  }
  return x;
}
D
cat > fake_test.sh <<'D'
echo "args=$*"
mkdir -p coverage
cat > coverage/lcov.info <<'L'
SF:lib/a.dart
DA:1,1
DA:2,1
DA:3,1
BRDA:1,0,0,1
BRDA:2,0,0,1
BRDA:3,0,0,0
end_of_record
SF:lib/b.dart
DA:2,1
BRDA:2,0,0,1
end_of_record
SF:lib/c.dart
DA:1,1
DA:2,1
DA:3,1
BRDA:1,0,0,1
BRDA:2,0,0,1
end_of_record
L
D
