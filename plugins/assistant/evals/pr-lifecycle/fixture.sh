#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# origin.git is a local bare remote; stub/gh keeps one PR's state in gh.state
# and logs every create / ready it receives, so no network is touched.
set -euo pipefail
git init -q --bare origin.git
git clone -q origin.git wt 2>/dev/null
cd wt
git config user.email e@e; git config user.name e
mkdir -p .claude lib/l10n
printf 'vcs: git\ncoverage: plan-coverage -- flutter test\nmutation: none\nui_strings: lib/l10n/*.arb\n' > .claude/assistant.md
printf '.claude/.assistant/\n' > .gitignore
echo '{}' > lib/l10n/app_en.arb
git add -A; git commit -qm base; git push -q origin HEAD:main 2>/dev/null
git remote set-head origin main 2>/dev/null || git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
git switch -qc task/x
echo '{"hi":"Hi"}' > lib/l10n/app_en.arb
git commit -qam 'task: add a string'
cd ..
mkdir -p stub
cat > stub/gh <<'SH'
#!/usr/bin/env bash
state="$EVAL_WS/gh.state"
case "$1 $2" in
  "auth status"|"repo view") exit 0 ;;
  "pr view")
    [ -f "$state" ] || exit 1
    read -r kind num < "$state"
    case "$*" in
      *isDraft*) echo "$num $([ "$kind" = draft ] && echo true || echo false) main" ;;
      *) echo "https://github.com/o/r/pull/$num" ;;
    esac ;;
  "pr create") echo "gh: $*" >> "$EVAL_WS/gh.log"; echo "draft 7" > "$state"; echo "https://github.com/o/r/pull/7" ;;
  "pr ready")  echo "gh: $*" >> "$EVAL_WS/gh.log"; echo "ready 7" > "$state" ;;
  *) exit 1 ;;
esac
SH
chmod +x stub/gh
