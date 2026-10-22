#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# origin.git is a local bare remote; stub/gh holds one draft PR whose checks come
# from $GH_CHECKS ("<bucket> <name>|…", or "none" for no check reported yet), and
# logs every ready it receives, so no network is touched.
set -euo pipefail
git init -q --bare origin.git
git clone -q origin.git wt 2>/dev/null
cd wt
git config user.email e@e; git config user.name e
mkdir -p .claude .github/workflows
printf 'vcs: git\n' > .claude/assistant.md
printf '.claude/.assistant/\n' > .gitignore
printf 'on: pull_request\n' > .github/workflows/ci.yml
git add -A; git commit -qm base; git push -q origin HEAD:main 2>/dev/null
git remote set-head origin main 2>/dev/null || git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
git switch -qc task/x
echo change > note.txt
git add -A; git commit -qm 'task: add a note'
git push -q -u origin HEAD 2>/dev/null
cd ..
echo "draft 7" > gh.state
mkdir -p stub
cat > stub/gh <<'SH'
#!/usr/bin/env bash
state="$EVAL_WS/gh.state"
case "$1 $2" in
  "auth status"|"repo view") exit 0 ;;
  "pr view")
    read -r kind num < "$state"
    case "$*" in
      *isDraft*) echo "$num $([ "$kind" = draft ] && echo true || echo false) main" ;;
      *) echo "https://github.com/o/r/pull/$num" ;;
    esac ;;
  "pr checks")
    [ "$GH_CHECKS" = none ] && { echo "no checks reported on the 'task/x' branch" >&2; exit 1; }
    tr '|' '\n' <<< "$GH_CHECKS" ;;
  "pr ready") echo "gh: $*" >> "$EVAL_WS/gh.log"; echo "ready 7" > "$state" ;;
  *) exit 1 ;;
esac
SH
chmod +x stub/gh
