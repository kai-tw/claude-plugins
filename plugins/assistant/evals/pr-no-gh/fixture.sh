#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# Three ways to have no usable gh: nogh/ is a PATH with every tool asst-pr needs
# except gh; stub/gh fails `auth status` when GH_AUTH=no and `repo view` when
# GH_REPO=no. origin.git is a local bare remote, so the push still works.
set -euo pipefail
git init -q --bare origin.git
git clone -q origin.git wt 2>/dev/null
cd wt
git config user.email e@e; git config user.name e
mkdir -p .claude
printf 'vcs: git\ncoverage: none\nmutation: none\nui_strings: none\n' > .claude/assistant.md
printf '.claude/.assistant/\n' > .gitignore
git add -A; git commit -qm base; git push -q origin HEAD:main 2>/dev/null
git remote set-head origin main 2>/dev/null || git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
git switch -qc task/y
echo y > y.txt; git add y.txt; git commit -qm 'task: y'
cd ..
mkdir -p nogh stub
for c in bash env git sed head dirname stat cat ls sort tail mkdir mv rm; do
  ln -s "$(command -v "$c")" "nogh/$c"
done
cat > stub/gh <<'SH'
#!/usr/bin/env bash
case "$1 $2" in
  "auth status") [ "${GH_AUTH:-}" != no ] ;;
  "repo view")   [ "${GH_REPO:-}" != no ] ;;
  *) echo "gh: $*" >> "$EVAL_WS/gh.log"; exit 1 ;;
esac
SH
chmod +x stub/gh
