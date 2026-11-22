#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# fake_test.sh stands in for `flutter test`: it appends a line to runs.txt each time
# it runs, then writes a fully executed lcov. check.sh points TEST_QUEUE_DIR under
# /dev/null, where no directory can be made, runs plan-coverage on lib/a.dart in the
# background, kills it if it is still running after 15 s so a run that never ends
# fails the case instead of hanging the runner, and prints what the case grades.
set -euo pipefail
git init -q
mkdir -p lib report
printf 'int a() => 1;\n' > lib/a.dart
cat > fake_test.sh <<'SH'
echo ran >> "$(dirname "$0")/runs.txt"
mkdir -p coverage
printf 'SF:lib/a.dart\nDA:1,1\nend_of_record\n' > coverage/lcov.info
SH
cat > check.sh <<'SH'
w=$PWD
export TEST_QUEUE_DIR=/dev/null/slots PLAN_QA_REPORT_DIR="$w/report"
plan-coverage --files lib/a.dart -- bash "$w/fake_test.sh" > out.txt 2>&1 &
pc=$!
for _ in $(seq 1 75); do kill -0 "$pc" 2>/dev/null || break; sleep 0.2; done
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
SH
