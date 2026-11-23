#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# A repo with two branches off `main`: `ci` changes only a workflow file, `code`
# changes lib/a.dart. fake_test.sh stands in for `flutter test` and leaves a marker
# file when it runs. check.sh holds the only test slot for another repo: a live
# process locks slot-1 and writes into it that it started 65 s ago. check.sh runs
# plan-coverage on each branch, prints the output, exit code, seconds taken and
# whether the test command ran, then whether the holder still holds its slot.
# A slot is held while its file is locked: slot() reports whether an exclusive flock
# could be taken on it right now.
set -euo pipefail
g() { git -c user.name=e -c user.email=e@e "$@"; }
printf 'echo ran > "$(dirname "$0")/ran"\n' > fake_test.sh
mkdir -p r/lib r/.github/workflows
cd r
printf 'int a() => 1;\n' > lib/a.dart
printf 'name: ci\n' > .github/workflows/pr-checks.yml
git init -q -b main && g add -A && g commit -qm base
git switch -qc ci; printf 'name: ci\non: pull_request\n' > .github/workflows/pr-checks.yml; g commit -qam ci
git switch -q main; git switch -qc code; printf 'int a() => 2;\n' > lib/a.dart; g commit -qam code
cd ..
cat > check.sh <<'SH'
w=$PWD
export TEST_QUEUE_DIR="$w/s" TEST_QUEUE_SLOTS=1 TEST_QUEUE_WAIT=5 PLAN_QA_REPORT_DIR="$w/report"
mkdir -p s report
slot() {
  if [ ! -e "$1" ]; then echo free; elif [ ! -f "$1" ]; then echo not-a-lock-file
  elif perl -MFcntl=:flock -e 'open(my $f, "<", $ARGV[0]) or exit 2; exit(flock($f, LOCK_EX | LOCK_NB) ? 0 : 1)' "$1"; then echo free
  else echo held; fi
}
perl -MFcntl=:flock -e 'open(my $f, ">>", $ARGV[0]) or die; flock($f, LOCK_EX) or die; truncate($f, 0);
  syswrite($f, "name=other-repo\npid=$$\nstarted=" . (time - 65) . "\ncmd=flutter test test/\n"); sleep 60' "$w/s/slot-1" >/dev/null 2>&1 &
holder=$!
for _ in $(seq 1 25); do [ "$(slot s/slot-1)" = held ] && break; sleep 0.2; done
for b in ci code; do
  start=$(date +%s)
  (cd r && git switch -q "$b" && plan-coverage --diff main -- bash "$w/fake_test.sh") > "out-$b.txt" 2>&1
  rc=$?
  echo "$b: took=$(( $(date +%s) - start ))s"
  sed "s/^/$b: /" "out-$b.txt"
  echo "$b: rc=$rc"
  if [ -e ran ]; then echo "$b: test-command=ran"; else echo "$b: test-command=not-run"; fi
done
echo "holder-after=$(slot s/slot-1) $(grep ^name= s/slot-1)"
kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
echo "left-running=$(pgrep -f "$w/" | grep -c .)"
SH
