#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# origin.git is a local bare remote with main and staging; the project config sends task
# PRs into staging. staging carries one commit main lacks, and the task branch
# starts from staging. stub/gh logs every call to gh.log; `pr view` finds a draft
# PR whose base is $GH_BASE unless GH_HAS_PR=0, and `pr list` finds none.
set -euo pipefail
git init -q --bare origin.git
git clone -q origin.git wt 2>/dev/null
cd wt
git config user.email e@e; git config user.name e
mkdir -p .claude
printf 'vcs: git\nbase_branch: staging\n' > .claude/assistant.md
printf '.claude/.assistant/\n' > .gitignore
mkdir -p .github/workflows; printf 'on: workflow_dispatch\n' > .github/workflows/release.yml
git add -A; git commit -qm base; git push -q origin HEAD:main 2>/dev/null
git remote set-head origin main 2>/dev/null || git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
git switch -qc staging
echo feature > feature.txt
git add -A; git commit -qm 'staging: add a feature'
git push -q -u origin HEAD 2>/dev/null
git switch -qc task/x
echo change > note.txt
git add -A; git commit -qm 'task: add a note'
cd ..
mkdir -p stub
cat > stub/gh <<'SH'
#!/usr/bin/env bash
echo "gh $*" >> "$EVAL_WS/gh.log"
case "$1 $2" in
  "auth status"|"repo view") exit 0 ;;
  "pr view")
    [ "${GH_HAS_PR:-1}" = 0 ] && exit 1
    case "$*" in
      *isDraft*) echo "7 true ${GH_BASE:-staging}" ;;
      *body*) echo "a description" ;;
      *) echo "https://github.com/o/r/pull/7" ;;
    esac ;;
  "pr create") echo "https://github.com/o/r/pull/8" ;;
  "pr list"|"workflow run") exit 0 ;;
  *) exit 1 ;;
esac
SH
chmod +x stub/gh

# An svn project, to check that release says it is git only.
mkdir -p svnproj/.claude
printf 'vcs: svn\nbase_branch: staging\n' > svnproj/.claude/assistant.md
