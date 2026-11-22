#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# fake_test.sh stands in for `flutter test`: it appends a line to runs.txt each time
# it runs, then writes a fully executed lcov. check.sh runs plan-coverage on
# lib/a.dart twice, each in the background and killed if it is still running after
# 15 s, so a run that never ends fails the case instead of hanging the runner:
# `dev-null` points TEST_QUEUE_DIR under /dev/null, where no directory can be made;
# `read-only` points it at an empty directory nobody can write to, where no lock
# file can be made. It prints what the case grades for each.
set -euo pipefail
git init -q
mkdir -p lib report ro
printf 'int a() => 1;\n' > lib/a.dart
cat > fake_test.sh <<'SH'
echo ran >> "$(dirname "$0")/runs.txt"
mkdir -p coverage
printf 'SF:lib/a.dart\nDA:1,1\nend_of_record\n' > coverage/lcov.info
SH
cat > check.sh <<'SH'
w=$PWD
export PLAN_QA_REPORT_DIR="$w/report" TEST_QUEUE_WAIT=0
chmod 555 ro
for leg in dev-null:/dev/null/slots "read-only:$w/ro"; do
  name=${leg%%:*}
  rm -rf runs.txt coverage
  TEST_QUEUE_DIR=${leg#*:} plan-coverage --files lib/a.dart -- bash "$w/fake_test.sh" > out.txt 2>&1 &
  pc=$!
  for _ in $(seq 1 75); do kill -0 "$pc" 2>/dev/null || break; sleep 0.2; done
  {
    if kill -0 "$pc" 2>/dev/null; then
      kill -KILL "$pc"; wait "$pc" 2>/dev/null
      echo "finished=no"; echo "rc=killed"
    else
      wait "$pc"; rc=$?
      echo "finished=yes"; echo "rc=$rc"
    fi
    echo "runs=$(cat runs.txt 2>/dev/null | grep -c .)"
    echo "warnings=$(grep -c WARNING out.txt)"
    grep -m1 WARNING out.txt
    echo "left-running=$(pgrep -f "$w/" | grep -c .)"
  } > result.txt
  sed "s/^/$name: /" result.txt
done
chmod 755 ro
SH
