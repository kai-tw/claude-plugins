#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# fake_test.sh stands in for a `flutter test` that runs 10 s: it records its pid and
# its child's; left alone it leaves a marker file and writes a fully executed lcov.
# quick_test.sh stands in for the next run's `flutter test`: it leaves a marker file
# and writes a fully executed lcov at once.
# check.sh starts plan-coverage on lib/a.dart with one free slot through perl, which
# makes it a process group leader. Once the test command has started it sends KILL
# to that whole group, so nothing of plan-coverage gets to run again, and probes the
# slot's lock for up to 1 s, before anything else touches the queue. Then it runs
# plan-coverage once more without waiting, prints what the case grades and kills
# whatever is left.
# A slot is held while its file is locked: slot() reports whether an exclusive flock
# could be taken on it right now.
set -euo pipefail
git init -q
mkdir -p lib report s
printf 'int a() => 1;\n' > lib/a.dart
cat > fake_test.sh <<'SH'
w=$(dirname "$0")
sleep 10 &
echo "$!" > "$w/sleep.pid"
echo "$$" > "$w/test.pid"
wait
echo finished > "$w/finished"
mkdir -p coverage
printf 'SF:lib/a.dart\nDA:1,1\nend_of_record\n' > coverage/lcov.info
SH
cat > quick_test.sh <<'SH'
echo ran > "$(dirname "$0")/quick-ran"
mkdir -p coverage
printf 'SF:lib/a.dart\nDA:1,1\nend_of_record\n' > coverage/lcov.info
SH
cat > check.sh <<'SH'
w=$PWD
export TEST_QUEUE_DIR="$w/s" TEST_QUEUE_SLOTS=1 TEST_QUEUE_WAIT=0 PLAN_QA_REPORT_DIR="$w/report"
slot() {
  if [ ! -e "$1" ]; then echo free; elif [ ! -f "$1" ]; then echo not-a-lock-file
  elif perl -MFcntl=:flock -e 'open(my $f, "<", $ARGV[0]) or exit 2; exit(flock($f, LOCK_EX | LOCK_NB) ? 0 : 1)' "$1"; then echo free
  else echo held; fi
}
perl -e 'setpgrp(0, 0); exec @ARGV or die "exec: $!"' \
  plan-coverage --files lib/a.dart -- bash "$w/fake_test.sh" > out.txt 2>&1 &
pc=$!
for _ in $(seq 1 50); do [ -s test.pid ] && [ -s sleep.pid ] && break; sleep 0.2; done
if [ -s test.pid ]; then echo "test-started=yes"; else echo "test-started=no"; fi
echo "slot-before-kill=$(slot s/slot-1)"
kill -KILL -- "-$pc"
wait "$pc" 2>/dev/null
for _ in $(seq 1 5); do [ "$(slot s/slot-1)" = free ] && break; sleep 0.2; done
echo "slot-after-kill=$(slot s/slot-1)"
echo "left-in-group=$(pgrep -g "$pc" | grep -c .)"
if [ -e finished ]; then echo "test-command=finished"; else echo "test-command=killed"; fi
plan-coverage --files lib/a.dart -- bash "$w/quick_test.sh" > next.txt 2>&1
echo "next-rc=$?"
if [ -e quick-ran ]; then echo "next-ran=yes"; else echo "next-ran=no"; fi
echo "left-running=$(pgrep -f "$w/" | grep -c .)"
kill -KILL -- "-$pc" 2>/dev/null
kill -KILL $(cat test.pid sleep.pid 2>/dev/null) 2>/dev/null
SH
