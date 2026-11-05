#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# wt is a clone on task/x; stub/gh answers `pr view` with the line in pr.state
# ("<number> <state> <merge commit>").
set -euo pipefail
git init -q --bare origin.git
git clone -q origin.git wt 2>/dev/null
cd wt
git config user.email e@e; git config user.name e
mkdir -p .claude
printf 'vcs: git\n' > .claude/assistant.md
printf '.claude/.assistant/\n' > .gitignore
git add -A; git commit -qm base; git push -q origin HEAD:main 2>/dev/null
git remote set-head origin main 2>/dev/null || git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
git switch -qc task/x
cd ..
mkdir -p stub
cat > stub/gh <<'SH'
#!/usr/bin/env bash
case "$1 $2" in
  "auth status"|"repo view") exit 0 ;;
  "pr view") cat "$EVAL_WS/pr.state" ;;
  *) exit 1 ;;
esac
SH
chmod +x stub/gh
