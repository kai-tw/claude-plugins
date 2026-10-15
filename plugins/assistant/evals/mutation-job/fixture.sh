#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# origin.git is a local bare remote; wt is a clone whose adapter runs
# plan-mutation after a worktree_init that generates lib/made.g.dart, or fails
# while init.fail exists. merged.sha is main's tip, which wt is not checked
# out at; it has lib/a.dart … lib/d.dart.
# stub/plan-mutation logs its arguments, commit, directory and the journal it
# starts from, and ends the way stub.mode says; `abort` first writes two
# journal lines, as a run cut off part-way would have.
# stub/gh logs what it posts; GH_OFF=1 makes it unusable.
set -euo pipefail
git init -q --bare origin.git
git clone -q origin.git wt 2>/dev/null
cd wt
git config user.email e@e; git config user.name e
mkdir -p .claude lib
printf 'vcs: git\nmutation: plan-mutation --workers 2 -- flutter test\nworktree_init: [ -e "$EVAL_WS/init.fail" ] && exit 3; echo made > lib/made.g.dart\n' > .claude/assistant.md
printf '.claude/.assistant/\n*.g.dart\n' > .gitignore
git add -A; git commit -qm base
for f in a b c d; do echo "int $f() => 1;" > lib/$f.dart; done
git add -A; git commit -qm merged; git rev-parse HEAD > ../merged.sha
git push -q origin HEAD:main 2>/dev/null
git checkout -q HEAD~1
cd ..
mkdir -p stub
cat > stub/plan-mutation <<'SH'
#!/usr/bin/env bash
keep=$(printf '%s\n' "$@" | sed -n '/^--keep-dir$/{n;p;}')
j="$keep/plan-mutation-dart.jsonl"
echo "plan-mutation $* @ $(git rev-parse HEAD) in $PWD from $([ -f "$j" ] && grep -c . "$j" || echo 0) journal line(s), generated: $([ -f lib/made.g.dart ] && echo yes || echo no)" >> "$EVAL_WS/pm.log"
case "$(cat "$EVAL_WS/stub.mode")" in
  pass)    echo "PASS 90%" ;;
  blocked) echo "FAIL 50% survivor: 1 -> 2"; echo "plan-mutation: BLOCKED." >&2; exit 1 ;;
  abort)   printf 'header\nmutant 1\n' > "$j"; echo "plan-mutation: ABORTED (over-budget)" >&2; exit 1 ;;
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
