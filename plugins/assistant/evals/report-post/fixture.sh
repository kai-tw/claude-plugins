#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# wt is pushed to a local bare remote; stub/gh answers `pr view` with PR 9 unless
# GH_NOPR=yes, and writes every comment body to comments.log.
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
git switch -qc local-only
cd ..
mkdir -p stub
cat > stub/gh <<'SH'
#!/usr/bin/env bash
case "$1 $2" in
  "auth status"|"repo view") exit 0 ;;
  "pr view") [ "${GH_NOPR:-}" = yes ] && exit 1; echo 9 ;;
  "pr comment") { echo "--- comment on #$3"; cat; } >> "$EVAL_WS/comments.log" ;;
  *) exit 1 ;;
esac
SH
chmod +x stub/gh
