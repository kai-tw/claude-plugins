#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh feeds intercept.sh trap and healthy commands and prints whether the expected rule fired.
set -euo pipefail
cat > check.sh <<'SH'
root=$1; mkdir -p flags; n=0
run() {
  n=$((n+1))
  ids=$(jq -n --arg c "$3" --arg s "eval-$n" '{session_id:$s,tool_input:{command:$c}}' \
    | TMPDIR=$PWD/flags bash "$root/hooks/intercept.sh" 2>/dev/null \
    | jq -r '.hookSpecificOutput.additionalContext // empty' | grep -oE '⚠️  [a-z-]+' | cut -d' ' -f3 | sort -u | tr '\n' ' ')
  if [ "$2" = - ]; then [ -z "$ids" ] && v=quiet || v="noisy($ids)"
  else case " $ids " in *" $2 "*) v=hit ;; *) v=miss ;; esac; fi
  echo "$1=$v"
}
run bad-test-tail   pipe-exit    'flutter test 2>&1 | tail -25'
run bad-build-head  pipe-exit    'cd app && npm run build | head -40'
run bad-build-echo  pipe-exit    'flutter build ios > b.log 2>&1; echo "EXIT=$?"; tail -20 b.log'
run bad-grep-status pipe-exit    'grep -rw Foo lib | head -3; echo "exit=$?"'
run bad-tmp-log     shared-tmp   'flutter test > /tmp/full_test_run.log 2>&1'
run bad-tmp-tee     shared-tmp   'npm test 2>&1 | tee /tmp/test.log'
run bad-sed-b       bsd-sed-b    "sed -i '' 's/\\bFoo\\b/Bar/g' lib/a.dart"
run bad-checkout    restore-head 'git checkout -- lib/a.dart'
run bad-checkout-h  restore-head 'git checkout HEAD -- lib/a.dart'
run bad-restore     restore-head 'git restore lib/a.dart'
run bad-format-dir  format-dir   'dart format lib'
run bad-fix-bare    format-dir   'dart fix --apply'
run bad-fix-dir     format-dir   'dart fix --apply lib && git status'
run ok-log-head     - 'git log --oneline | head -5'
run ok-test-verdict - 'flutter test > "$s/t.log" 2>&1; grep -E "All tests passed|Some tests failed" "$s/t.log" | tail -1'
run ok-test-and     - 'npm test && git log --oneline | head -3'
run ok-scratch-log  - 'flutter test > /private/tmp/claude-501/x/scratchpad/t.log 2>&1'
run ok-tmp-read     - 'tail -20 /tmp/build.log'
run ok-sed-plain    - "sed -i '' 's/Foo/Bar/g' lib/a.dart"
run ok-perl-b       - "perl -pi -e 's/\\bFoo\\b/Bar/g' lib/a.dart"
run ok-unstage      - 'git restore --staged lib/a.dart'
run ok-branch       - 'git checkout -b feat && git checkout main'
run ok-format-file  - 'dart format lib/a.dart test/a_test.dart'
run ok-fix-scoped   - 'dart fix --apply --code=unused_import lib/a.dart'
run ok-last         - 'echo done'
SH
