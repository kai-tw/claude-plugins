#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# origin.git is a local bare remote; wt is a clone whose adapter runs
# plan-mutation, checked out one commit behind main (main's tip is in tip.sha).
# The queue holds lib/a.dart (PRs 7 and 9), lib/b.dart, lib/c.dart and
# lib/gone.dart, which main no longer has. stub/plan-mutation logs its
# arguments and the commit it ran on, and ends the way stub.mode says.
# stub/gh logs what it posts; GH_OFF=1 makes it unusable.
set -euo pipefail
git init -q --bare origin.git
git clone -q origin.git wt 2>/dev/null
cd wt
git config user.email e@e; git config user.name e
mkdir -p .claude lib
printf 'vcs: git\nmutation: plan-mutation --workers 2 -- flutter test\n' > .claude/assistant.md
printf '.claude/.assistant/\n' > .gitignore
for f in a b c; do echo "int $f() => 1;" > lib/$f.dart; done
git add -A; git commit -qm base
echo 'int a() => 2;' > lib/a.dart
git commit -qam merged; git rev-parse HEAD > ../tip.sha
git push -q origin HEAD:main 2>/dev/null
git remote set-head origin main 2>/dev/null || git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
git checkout -q HEAD~1
q="$(dirname "$0")/../../bin/asst-mutation-queue"
"$q" add 7 lib/a.dart lib/b.dart lib/gone.dart >/dev/null
"$q" add 9 lib/a.dart lib/c.dart >/dev/null
cd ..
mkdir -p stub
cat > stub/plan-mutation <<'SH'
#!/usr/bin/env bash
echo "plan-mutation $* @ $(git rev-parse HEAD)" >> "$EVAL_WS/pm.log"
case "$(cat "$EVAL_WS/stub.mode")" in
  pass)    echo "lib/a.dart PASS 90%" ;;
  blocked) echo "lib/a.dart FAIL 50% survivor: 2 -> 3"; echo "plan-mutation: BLOCKED." >&2; exit 1 ;;
  abort)   echo "plan-mutation: ABORTED (over-budget)" >&2; exit 1 ;;
esac
SH
cat > stub/gh <<'SH'
#!/usr/bin/env bash
[ -n "${GH_OFF:-}" ] && exit 1
case "$1 $2" in
  "auth status"|"repo view") exit 0 ;;
  "pr comment")   echo "gh: $1 $2 $3" >> "$EVAL_WS/gh.log"; echo "https://github.com/o/r/pull/$3#c1" ;;
  "issue create") echo "gh: $1 $2 $4" >> "$EVAL_WS/gh.log"; echo "https://github.com/o/r/issues/9" ;;
  *) exit 1 ;;
esac
SH
chmod +x stub/plan-mutation stub/gh
