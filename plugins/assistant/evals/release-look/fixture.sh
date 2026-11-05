#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# origin.git is a local bare remote with main and staging, staging one commit
# ahead; wt is a clone whose project config sends task PRs into staging and which
# has a release.yml. stub/gh logs every call to gh.log, finds run 4242 for any
# release, and answers `run view` with run.state, which ./state writes.
set -euo pipefail
git init -q --bare origin.git
git clone -q origin.git wt 2>/dev/null
cd wt
git config user.email e@e; git config user.name e
mkdir -p .claude .github/workflows
printf 'vcs: git\nbase_branch: staging\n' > .claude/assistant.md
printf '.claude/.assistant/\n' > .gitignore
printf 'on: workflow_dispatch\n' > .github/workflows/release.yml
git add -A; git commit -qm base; git push -q origin HEAD:main 2>/dev/null
git remote set-head origin main 2>/dev/null || git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
git switch -qc staging
echo feature > feature.txt
git add -A; git commit -qm 'staging: add a feature'
git push -q -u origin HEAD 2>/dev/null
cd ..
mkdir -p stub
cat > stub/gh <<'SH'
#!/usr/bin/env bash
echo "gh $*" >> "$EVAL_WS/gh.log"
case "$1 $2" in
  "auth status") exit 0 ;;
  "repo view") case "$*" in *nameWithOwner*) echo o/r ;; esac ;;
  "workflow run") exit 0 ;;
  "run list") echo 4242 ;;
  "run view") cat "$EVAL_WS/run.state" ;;
  *) exit 1 ;;
esac
SH
chmod +x stub/gh
# state <status> <conclusion> <sha> — what `gh run view` says of run 4242.
cat > state <<'SH'
#!/usr/bin/env bash
printf '%s\t%s\t%s\t%s\n' "$1" "$2" https://github.com/o/r/actions/runs/4242 "Release $3" > "$EVAL_WS/run.state"
SH
chmod +x state
