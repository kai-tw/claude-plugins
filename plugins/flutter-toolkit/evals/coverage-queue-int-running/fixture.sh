#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# fake_test.sh stands in for a `flutter test` that runs 10 s: it records its pid,
# and on INT or TERM takes 1 s to shut down, records whether its slot is still
# locked at that point and exits 143; left alone it leaves a marker file and writes a
# fully executed lcov.
# check.sh starts plan-coverage on lib/a.dart with one free slot through perl, which
# restores INT's default action (a background job of a script starts with INT
# ignored) and makes it a process group leader, as a terminal's foreground job is;
# once the test command has started it sends INT to that group, kills the group if
# plan-coverage is still running 20 s later, prints what the case grades and kills
# whatever is left.
# A slot is held while its file is locked: slot() reports whether an exclusive flock
# could be taken on it right now.
set -euo pipefail
git init -q
mkdir -p lib report s
printf 'int a() => 1;\n' > lib/a.dart
cat > fake_test.sh <<'SH'
w=$(dirname "$0")
slot() {
  if [ ! -e "$1" ]; then echo free; elif [ ! -f "$1" ]; then echo not-a-lock-file
  elif perl -MFcntl=:flock -e 'open(my $f, "<", $ARGV[0]) or exit 2; exit(flock($f, LOCK_EX | LOCK_NB) ? 0 : 1)' "$1"; then echo free
  else echo held; fi
}
trap 'trap "" INT TERM; kill "$s" 2>/dev/null; sleep 1; echo "slot-at-shutdown=$(slot "$TEST_QUEUE_DIR/slot-1")" > "$w/stopped.txt"; exit 143' INT TERM
sleep 10 &
s=$!
echo "$s" > "$w/sleep.pid"
echo "$$" > "$w/test.pid"
wait "$s"
echo finished > "$w/finished"
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
perl -e '$SIG{INT} = "DEFAULT"; setpgrp(0, 0); exec @ARGV or die "exec: $!"' \
  plan-coverage --files lib/a.dart -- bash "$w/fake_test.sh" > out.txt 2>&1 &
pc=$!
for _ in $(seq 1 50); do [ -s test.pid ] && break; sleep 0.2; done
if [ -s test.pid ]; then echo "test-started=yes"; else echo "test-started=no"; fi
kill -INT -- "-$pc"
for _ in $(seq 1 100); do kill -0 "$pc" 2>/dev/null || break; sleep 0.2; done
if kill -0 "$pc" 2>/dev/null; then
  kill -KILL -- "-$pc"; wait "$pc" 2>/dev/null
  echo "stopped=no"; echo "rc=killed"
else
  wait "$pc"; rc=$?
  echo "stopped=yes"; echo "rc=$rc"
fi
sleep 0.2
tp=$(cat test.pid 2>/dev/null)
if [ -n "$tp" ] && kill -0 "$tp" 2>/dev/null; then echo "test-process=running"; else echo "test-process=gone"; fi
if [ -e finished ]; then echo "test-command=finished"; else echo "test-command=cut-short"; fi
cat stopped.txt 2>/dev/null || echo "slot-at-shutdown=no-signal"
echo "slot-after=$(slot s/slot-1)"
echo "left-in-group=$(pgrep -g "$pc" | grep -c .)"
echo "left-running=$(pgrep -f "$w/" | grep -c .)"
kill -KILL -- "-$pc" 2>/dev/null
kill -KILL $tp $(cat sleep.pid 2>/dev/null) 2>/dev/null
SH
