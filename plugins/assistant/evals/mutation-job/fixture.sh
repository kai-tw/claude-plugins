#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# origin.git is a local bare remote; wt is a clone whose adapter runs
# plan-mutation after a worktree_init that generates lib/made.g.dart, or fails
# while init.fail exists; wt is checked out behind main. The queue holds
# lib/a.dart (PRs 7 and 9), lib/b.dart, lib/c.dart, lib/d.dart and
# lib/gone.dart, which main doesn't have.
# lib/a.dart was claimed at tip1, saved a 2-line journal and lost its session:
# it is swept back to pending while main has moved on to tip2.
# stub/plan-mutation logs its arguments, commit, directory and the journal it
# starts from, and ends the way stub.mode says; `slow` writes three journal
# lines, waits for the heartbeat and prints the queue's view of itself.
# stub/gh logs what it posts; GH_OFF=1 makes it unusable.
set -euo pipefail
q="$(cd "$(dirname "$0")/../.." && pwd)/bin/asst-mutation-queue"
git init -q --bare origin.git
git clone -q origin.git wt 2>/dev/null
cd wt
git config user.email e@e; git config user.name e
mkdir -p .claude lib
printf 'vcs: git\nmutation: plan-mutation --workers 2 -- flutter test\nworktree_init: [ -e "$EVAL_WS/init.fail" ] && exit 3; echo made > lib/made.g.dart\n' > .claude/assistant.md
printf '.claude/.assistant/\n*.g.dart\n' > .gitignore
for f in a b c d; do echo "int $f() => 1;" > lib/$f.dart; done
git add -A; git commit -qm base
echo 'int a() => 2;' > lib/a.dart
git commit -qam merged; git rev-parse HEAD > ../tip1.sha
git push -q origin HEAD:main 2>/dev/null
git remote set-head origin main 2>/dev/null || git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
"$q" add 7 lib/a.dart lib/b.dart lib/gone.dart >/dev/null
"$q" add 9 lib/a.dart lib/c.dart lib/d.dart >/dev/null
"$q" claim >/dev/null
printf 'header\nmutant 1\n' > ../saved.jsonl
"$q" save lib/a.dart "$PWD/../saved.jsonl" >/dev/null
echo 'int b() => 2;' > lib/b.dart
git commit -qam later; git rev-parse HEAD > ../tip2.sha
git push -q origin HEAD:main 2>/dev/null
sleep 1
"$q" sweep 0 >/dev/null
git checkout -q HEAD~2
cd ..
mkdir -p stub
cat > stub/plan-mutation <<'SH'
#!/usr/bin/env bash
keep=$(printf '%s\n' "$@" | sed -n '/^--keep-dir$/{n;p;}')
j="$keep/plan-mutation-dart.jsonl"
echo "plan-mutation $* @ $(git rev-parse HEAD) in $PWD from $([ -f "$j" ] && grep -c . "$j" || echo 0) journal line(s)" >> "$EVAL_WS/pm.log"
echo "generated: $([ -f lib/made.g.dart ] && echo yes || echo no)" >> "$EVAL_WS/pm.log"
case "$(cat "$EVAL_WS/stub.mode")" in
  pass)    echo "lib/a.dart PASS 90%" ;;
  slow)    printf 'header\nm1\nm2\n' > "$j"; sleep 3
           asst-mutation-queue status | grep '^running' | sed 's/^/during: /' >> "$EVAL_WS/pm.log"
           echo "lib/b.dart FAIL 50% survivor: 2 -> 3"; echo "plan-mutation: BLOCKED." >&2; exit 1 ;;
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
