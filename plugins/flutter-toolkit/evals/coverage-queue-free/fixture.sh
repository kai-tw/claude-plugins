#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# Two test slots, slot-1 held by another repo as a live process. fake_test.sh stands
# in for `flutter test`: it records the slots it sees while it runs and the fields of
# slot-2's meta file, read the way a 7.x holder list reads them, then writes a fully
# executed lcov. check.sh runs plan-coverage on lib/a.dart and prints what the case
# grades.
set -euo pipefail
git init -q
mkdir -p lib report s/slot-1
printf 'int a() => 1;\n' > lib/a.dart
cat > fake_test.sh <<'SH'
m="$TEST_QUEUE_DIR/slot-2/meta"
f() { sed -n "s/^$1=//p" "$m" 2>/dev/null | head -1; }
pid=$(f pid) started=$(f started) age=
[ -n "$started" ] && age=$(( $(date +%s) - started ))
{
  echo "ran=1"
  echo "slots-during=$(ls "$TEST_QUEUE_DIR" | paste -sd, -)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then echo "meta-pid=alive"; else echo "meta-pid=${pid:-missing}"; fi
  echo "meta-name=$(f name)"
  if [ -n "$age" ] && [ "$age" -ge 0 ] && [ "$age" -le 60 ]; then echo "meta-started=recent"; else echo "meta-started=${started:-missing}"; fi
  echo "meta-cmd=$(f cmd)"
} > during.txt
mkdir -p coverage
printf 'SF:lib/a.dart\nDA:1,1\nend_of_record\n' > coverage/lcov.info
SH
cat > check.sh <<'SH'
export TEST_QUEUE_DIR="$PWD/s" TEST_QUEUE_SLOTS=2 TEST_QUEUE_WAIT=0 TEST_QUEUE_NAME=queue-eval PLAN_QA_REPORT_DIR="$PWD/report"
printf 'pid=%s\nname=other-repo\nsession=other-session\nstarted=%s\ncmd=flutter test test/\n' \
  "$$" "$(date +%s)" > s/slot-1/meta
plan-coverage --files lib/a.dart -- bash fake_test.sh >out.txt 2>&1
echo "rc=$?"
cat during.txt 2>/dev/null || echo "ran=0"
echo "slots-after=$(ls s | paste -sd, -) $(grep ^name= s/slot-1/meta)"
SH
