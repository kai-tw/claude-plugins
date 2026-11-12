#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# wt's task branch is pushed to a local bare remote; stub/gh logs every call to
# gh.log, so a put that reaches GitHub shows there.
set -euo pipefail
git init -q --bare origin.git
git clone -q origin.git wt 2>/dev/null
cd wt
git config user.email e@e; git config user.name e
mkdir -p .claude
printf 'vcs: git\n' > .claude/assistant.md
printf '.claude/.assistant/\n' > .gitignore
git add -A; git commit -qm base; git push -q origin HEAD:main 2>/dev/null
git switch -qc task/r; git push -q -u origin task/r 2>/dev/null
cd ..
mkdir -p stub
cat > stub/gh <<'SH'
#!/usr/bin/env bash
echo "gh $*" >> "$EVAL_WS/gh.log"
SH
chmod +x stub/gh
