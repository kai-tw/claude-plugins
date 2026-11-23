#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# Two test slots: slot-1 is locked by another repo's live process, slot-2 is unlocked
# and still holds a finished run's content. fake_test.sh stands in for `flutter test`:
# it records slot-2's fields, marks that it started, waits for check.sh to say go,
# then writes a fully executed lcov. check.sh runs plan-coverage on lib/a.dart, and
# while the test command runs, probes both slots' locks and starts a second
# plan-coverage that finds no free slot; it prints what the case grades.
# A slot is held while its file is locked: slot() reports whether an exclusive flock
# could be taken on it right now.
set -euo pipefail
git init -q
mkdir -p lib report s
printf 'int a() => 1;\n' > lib/a.dart
printf 'name=finished-repo\npid=1\nstarted=1\ncmd=flutter test test/old_test.dart\n' > s/slot-2
cat > fake_test.sh <<'SH'
w=$(dirname "$0")
f() { sed -n "s/^$1=//p" "$TEST_QUEUE_DIR/slot-2" 2>/dev/null | head -1; }
pid=$(f pid) started=$(f started) age=
[ -n "$started" ] && age=$(( $(date +%s) - started ))
{
  echo "ran=1"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then echo "meta-pid=alive"; else echo "meta-pid=${pid:-missing}"; fi
  echo "meta-name=$(f name)"
  if [ -n "$age" ] && [ "$age" -ge 0 ] && [ "$age" -le 60 ]; then echo "meta-started=recent"; else echo "meta-started=${started:-missing}"; fi
  echo "meta-cmd=$(f cmd)"
} > "$w/during.txt"
for _ in $(seq 1 50); do [ -e "$w/go" ] && break; sleep 0.2; done
mkdir -p coverage
printf 'SF:lib/a.dart\nDA:1,1\nend_of_record\n' > coverage/lcov.info
SH
printf 'echo ran > "$(dirname "$0")/second-ran"\n' > second_test.sh
cat > check.sh <<'SH'
w=$PWD
export TEST_QUEUE_DIR="$w/s" TEST_QUEUE_SLOTS=2 TEST_QUEUE_WAIT=0 TEST_QUEUE_NAME=queue-eval PLAN_QA_REPORT_DIR="$w/report"
slot() {
  if [ ! -e "$1" ]; then echo free; elif [ ! -f "$1" ]; then echo not-a-lock-file
  elif perl -MFcntl=:flock -e 'open(my $f, "<", $ARGV[0]) or exit 2; exit(flock($f, LOCK_EX | LOCK_NB) ? 0 : 1)' "$1"; then echo free
  else echo held; fi
}
perl -MFcntl=:flock -e 'open(my $f, ">>", $ARGV[0]) or die; flock($f, LOCK_EX) or die; truncate($f, 0);
  syswrite($f, "name=other-repo\npid=$$\nstarted=" . time . "\ncmd=flutter test test/\n"); sleep 30' "$w/s/slot-1" >/dev/null 2>&1 &
holder=$!
for _ in $(seq 1 25); do [ "$(slot s/slot-1)" = held ] && break; sleep 0.2; done
plan-coverage --files lib/a.dart -- bash "$w/fake_test.sh" > out.txt 2>&1 &
pc=$!
for _ in $(seq 1 50); do [ -s during.txt ] && break; sleep 0.2; done
echo "slots-during=$(slot s/slot-1),$(slot s/slot-2)"
TEST_QUEUE_NAME=second-run plan-coverage --files lib/a.dart -- bash "$w/second_test.sh" > second.txt 2>&1
echo "second-rc=$?"
if [ -e second-ran ]; then echo "second-ran=yes"; else echo "second-ran=no"; fi
echo "refusal-names=$(grep -oE 'other-repo|queue-eval' second.txt | sort -u | paste -sd, -)"
pid=$(sed -n 's/^pid=//p' s/slot-2 | head -1)
if [ -n "$pid" ] && grep -Eq "(^|[^0-9])$pid([^0-9]|$)" second.txt; then echo "refusal-pid=yes"; else echo "refusal-pid=no"; fi
if grep -q 'fake_test\.sh' second.txt && grep -q 'flutter test test/' second.txt; then echo "refusal-cmds=yes"; else echo "refusal-cmds=no"; fi
touch go
for _ in $(seq 1 100); do kill -0 "$pc" 2>/dev/null || break; sleep 0.2; done
kill -KILL "$pc" 2>/dev/null
wait "$pc"
echo "rc=$?"
cat during.txt 2>/dev/null || echo "ran=0"
echo "slots-after=$(slot s/slot-1),$(slot s/slot-2)"
echo "holder-content=$(grep ^name= s/slot-1)"
kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
echo "left-running=$(pgrep -f "$w/" | grep -c .)"
SH
