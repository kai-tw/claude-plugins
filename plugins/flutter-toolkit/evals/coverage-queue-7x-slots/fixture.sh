#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# home/ stands in for HOME, with no TEST_QUEUE_DIR set. fake_test.sh stands in for
# `flutter test`: it leaves a marker file when it runs, then writes a fully executed
# lcov. check.sh writes the only slot in $HOME/.claude/.flutter-toolkit/slots in the
# format a 7.x plan-test writes, first for a live holder that started 125 s ago, then
# for one whose process is gone, runs plan-coverage on lib/a.dart after each and
# prints what the case grades.
set -euo pipefail
git init -q
mkdir -p lib report home/.claude/.flutter-toolkit/slots/slot-1
printf 'int a() => 1;\n' > lib/a.dart
cat > fake_test.sh <<'SH'
echo ran > "ran-$RUN"
mkdir -p coverage
printf 'SF:lib/a.dart\nDA:1,1\nend_of_record\n' > coverage/lcov.info
SH
cat > check.sh <<'SH'
w=$PWD
slots="$w/home/.claude/.flutter-toolkit/slots"
unset TEST_QUEUE_DIR
export HOME="$w/home" TEST_QUEUE_SLOTS=1 TEST_QUEUE_WAIT=0 PLAN_QA_REPORT_DIR="$w/report"
meta() {
  printf 'pid=%s\nname=seven-x-repo\nsession=seven-x-session\nstarted=%s\ncmd=flutter test test/\n' \
    "$1" "$(( $(date +%s) - 125 ))" > "$slots/slot-1/meta"
}
for run in live dead; do
  if [ "$run" = live ]; then meta "$$"; else meta 999999; fi
  rm -rf coverage
  RUN=$run plan-coverage --files lib/a.dart -- bash fake_test.sh > "out-$run.txt" 2>&1
  rc=$?
  sed "s/^/$run: /" "out-$run.txt"
  echo "$run: rc=$rc"
  if [ -e "ran-$run" ]; then echo "$run: test-command=ran"; else echo "$run: test-command=not-run"; fi
  echo "$run: slots-after=$(ls "$slots" | paste -sd, -)"
done
SH
