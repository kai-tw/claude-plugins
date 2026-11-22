#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# fake_test.sh stands in for `flutter test`: it leaves a marker file when it runs,
# then writes a fully executed lcov. check.sh holds the only test slot for another
# repo with a process that locks slot-1 for 8 s, runs plan-coverage on lib/a.dart in
# the background, sends it TERM once it says it is waiting and kills it if it is still
# running 20 s later. Once plan-coverage has exited it ends the holder, gives anything
# still waiting 3 s to take the freed slot and prints what the case grades.
# A slot is held while its file is locked: slot() reports whether an exclusive flock
# could be taken on it right now.
set -euo pipefail
git init -q
mkdir -p lib report s
printf 'int a() => 1;\n' > lib/a.dart
cat > fake_test.sh <<'SH'
echo ran > "$(dirname "$0")/ran"
mkdir -p coverage
printf 'SF:lib/a.dart\nDA:1,1\nend_of_record\n' > coverage/lcov.info
SH
cat > check.sh <<'SH'
w=$PWD
export TEST_QUEUE_DIR="$w/s" TEST_QUEUE_SLOTS=1 TEST_QUEUE_WAIT=30 PLAN_QA_REPORT_DIR="$w/report"
slot() {
  if [ ! -e "$1" ]; then echo free; elif [ ! -f "$1" ]; then echo not-a-lock-file
  elif perl -MFcntl=:flock -e 'open(my $f, "<", $ARGV[0]) or exit 2; exit(flock($f, LOCK_EX | LOCK_NB) ? 0 : 1)' "$1"; then echo free
  else echo held; fi
}
perl -MFcntl=:flock -e 'open(my $f, ">>", $ARGV[0]) or die; flock($f, LOCK_EX) or die; truncate($f, 0);
  syswrite($f, "name=other-repo\npid=$$\nstarted=" . time . "\ncmd=flutter test test/\n"); sleep 8' "$w/s/slot-1" >/dev/null 2>&1 &
holder=$!
for _ in $(seq 1 25); do [ "$(slot s/slot-1)" = held ] && break; sleep 0.2; done
plan-coverage --files lib/a.dart -- bash "$w/fake_test.sh" > out.txt 2>&1 &
pc=$!
for _ in $(seq 1 50); do grep -q 'waiting up to' out.txt && break; sleep 0.2; done
if grep -q 'waiting up to' out.txt; then echo "waiting=yes"; else echo "waiting=no"; fi
echo "slot-at-term=$(slot s/slot-1)"
kill -TERM "$pc"
for _ in $(seq 1 100); do kill -0 "$pc" 2>/dev/null || break; sleep 0.2; done
if kill -0 "$pc" 2>/dev/null; then
  kill -KILL "$pc"; wait "$pc" 2>/dev/null
  echo "stopped=no"; echo "rc=killed"
else
  wait "$pc"; rc=$?
  echo "stopped=yes"; echo "rc=$rc"
fi
kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
sleep 3
if [ -e ran ]; then echo "test-command=ran"; else echo "test-command=not-run"; fi
echo "slot-after=$(slot s/slot-1)"
echo "slot-content=$(grep ^name= s/slot-1)"
echo "left-running=$(pgrep -f "$w/" | grep -c .)"
SH
