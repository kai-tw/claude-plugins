#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# Like pr-lifecycle, with coverage measured by CI, and a fake gh whose PR base
# and body come from ./base and ./body so the case can change them between runs.
set -euo pipefail
git init -q --bare origin.git
git clone -q origin.git wt 2>/dev/null
cd wt
git config user.email e@e; git config user.name e
mkdir -p .claude lib/l10n
printf 'vcs: git\ncoverage: ci\nui_strings: lib/l10n/*.arb\n' > .claude/assistant.md
printf '.claude/.assistant/\n' > .gitignore
echo '{}' > lib/l10n/app_en.arb
git add -A; git commit -qm base; git push -q origin HEAD:main 2>/dev/null
git remote set-head origin main 2>/dev/null || git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
git switch -qc task/x
echo '{"hi":"Hi"}' > lib/l10n/app_en.arb
git commit -qam 'task: add a string'
cd ..
echo main > base; echo 'What shipped.' > body
mkdir -p stub
cat > stub/gh <<'GH'
#!/usr/bin/env bash
state="$EVAL_WS/gh.state"
case "$1 $2" in
  "auth status"|"repo view") exit 0 ;;
  "pr view")
    [ -f "$state" ] || exit 1
    read -r kind num < "$state"
    case "$*" in
      *isDraft*) echo "$num $([ "$kind" = draft ] && echo true || echo false) $(cat "$EVAL_WS/base")" ;;
      *body*) cat "$EVAL_WS/body" ;;
      *) echo "https://github.com/o/r/pull/$num" ;;
    esac ;;
  "pr create") echo "draft 7" > "$state"; echo "https://github.com/o/r/pull/7" ;;
  "pr ready")  echo "gh: $*" >> "$EVAL_WS/gh.log"; echo "ready 7" > "$state" ;;
  *) exit 1 ;;
esac
GH
chmod +x stub/gh
