#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# A repo with two branches off `main`: `ci` changes only a workflow file, `code`
# changes lib/a.dart. fake_test.sh stands in for `flutter test` and leaves a marker
# file when it runs. check.sh holds the only test slot for another repo, as a live
# process that started 65 s ago, runs plan-coverage on each branch and prints the
# output, exit code, seconds taken and whether the test command ran.
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
mkdir -p s/slot-1 report
printf 'pid=%s\nname=other-repo\nsession=other-session\nstarted=%s\ncmd=flutter test test/\n' \
  "$$" "$(( $(date +%s) - 65 ))" > s/slot-1/meta
for b in ci code; do
  start=$(date +%s)
  (cd r && git switch -q "$b" && plan-coverage --diff main -- bash "$w/fake_test.sh") > "out-$b.txt" 2>&1
  rc=$?
  echo "$b: took=$(( $(date +%s) - start ))s"
  sed "s/^/$b: /" "out-$b.txt"
  echo "$b: rc=$rc"
  if [ -e ran ]; then echo "$b: test-command=ran"; else echo "$b: test-command=not-run"; fi
done
echo "holder-after=$(ls s | paste -sd, -) $(grep ^name= s/slot-1/meta)"
SH
