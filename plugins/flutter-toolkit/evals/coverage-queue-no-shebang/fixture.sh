#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# suite is the test command: an executable script with no shebang line. Its first
# line records whether bash runs it (BASH_VERSION is set only under bash); its
# second assigns a bash array, a syntax error under a POSIX sh such as dash, so the
# lcov it writes after that exists only when bash runs it. check.sh runs
# plan-coverage on lib/a.dart with suite in the background, killed if it is still
# running after 20 s, and prints what the case grades.
set -euo pipefail
git init -q
mkdir -p lib report s
printf 'int a() => 1;\n' > lib/a.dart
cat > suite <<'SH'
echo "shell=${BASH_VERSION:+bash}" > "$(dirname "$0")/shell.txt"
files=(lib/a.dart)
mkdir -p coverage
printf 'SF:%s\nDA:1,1\nend_of_record\n' "${files[0]}" > coverage/lcov.info
SH
chmod +x suite
cat > check.sh <<'SH'
w=$PWD
export TEST_QUEUE_DIR="$w/s" TEST_QUEUE_SLOTS=1 TEST_QUEUE_WAIT=0 PLAN_QA_REPORT_DIR="$w/report"
plan-coverage --files lib/a.dart -- "$w/suite" > out.txt 2>&1 &
pc=$!
for _ in $(seq 1 100); do kill -0 "$pc" 2>/dev/null || break; sleep 0.2; done
if kill -0 "$pc" 2>/dev/null; then
  kill -KILL "$pc"; wait "$pc" 2>/dev/null
  echo "rc=killed"
else
  wait "$pc"; echo "rc=$?"
fi
sed "s/^/out: /" out.txt
cat shell.txt 2>/dev/null || echo "shell=not-run"
echo "left-running=$(pgrep -f "$w/" | grep -c .)"
SH
