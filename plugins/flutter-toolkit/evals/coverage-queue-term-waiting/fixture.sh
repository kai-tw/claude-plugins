#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# fake_test.sh stands in for `flutter test`: it leaves a marker file when it runs,
# then writes a fully executed lcov. check.sh holds the only test slot for another
# repo with a `sleep 8` that ends on its own, runs plan-coverage on lib/a.dart in the
# background, sends it TERM once it says it is waiting, kills it if it is still
# running 20 s later, prints what the case grades and kills the holder.
set -euo pipefail
git init -q
mkdir -p lib report s/slot-1
printf 'int a() => 1;\n' > lib/a.dart
cat > fake_test.sh <<'SH'
echo ran > "$(dirname "$0")/ran"
mkdir -p coverage
printf 'SF:lib/a.dart\nDA:1,1\nend_of_record\n' > coverage/lcov.info
SH
cat > check.sh <<'SH'
w=$PWD
export TEST_QUEUE_DIR="$w/s" TEST_QUEUE_SLOTS=1 TEST_QUEUE_WAIT=30 PLAN_QA_REPORT_DIR="$w/report"
sleep 8 >/dev/null 2>&1 &
holder=$!
printf 'pid=%s\nname=other-repo\nsession=other-session\nstarted=%s\ncmd=flutter test test/\n' \
  "$holder" "$(date +%s)" > s/slot-1/meta
plan-coverage --files lib/a.dart -- bash "$w/fake_test.sh" > out.txt 2>&1 &
pc=$!
for _ in $(seq 1 50); do grep -q 'waiting up to' out.txt && break; sleep 0.2; done
if grep -q 'waiting up to' out.txt; then echo "waiting=yes"; else echo "waiting=no"; fi
if kill -0 "$holder" 2>/dev/null; then echo "holder-at-term=alive"; else echo "holder-at-term=gone"; fi
kill -TERM "$pc"
for _ in $(seq 1 100); do kill -0 "$pc" 2>/dev/null || break; sleep 0.2; done
if kill -0 "$pc" 2>/dev/null; then
  kill -KILL "$pc"; wait "$pc" 2>/dev/null
  echo "stopped=no"; echo "rc=killed"
else
  wait "$pc"; rc=$?
  echo "stopped=yes"; echo "rc=$rc"
fi
if [ -e ran ]; then echo "test-command=ran"; else echo "test-command=not-run"; fi
echo "own-slot=$(grep -lx "pid=$pc" s/*/meta 2>/dev/null | paste -sd, -)"
echo "slots-after=$(ls s | paste -sd, -) $(grep ^name= s/slot-1/meta 2>/dev/null)"
kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
echo "left-running=$(pgrep -f "$w/" | grep -c .)"
SH
