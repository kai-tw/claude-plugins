#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# A repo where `release` branched off `main` and changed lib/b.dart, and the
# branch `work` off `release` changes lib/c.dart. fake_test.sh stands in for
# `flutter test`, reporting coverage for neither file.
set -euo pipefail
g() { git -c user.name=e -c user.email=e@e "$@"; }
git init -q -b main
mkdir -p lib
for f in a b c; do echo "int $f() => 1;" > lib/$f.dart; done
cat > fake_test.sh <<'D'
mkdir -p coverage
printf 'SF:lib/a.dart\nDA:1,1\nend_of_record\n' > coverage/lcov.info
D
printf 'coverage/\nfake_test.sh\n' > .gitignore
g add -A; g commit -qm base
git switch -qc release; echo 'int b() => 2;' > lib/b.dart; g commit -qam release
git switch -qc work; echo 'int c() => 2;' > lib/c.dart; g commit -qam work
