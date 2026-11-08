#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# wt: branch leak adds a line naming acme/secret-app, branch clean adds a harmless line, both off a pushed main.
# stub/gh is repo acme/lib, visibility $GH_VIS (PUBLIC when unset); acme/secret-app is private; only #1 exists;
# every call is appended to gh.calls. check.sh feeds hooks/checks/disclosure.sh PreToolUse JSON and prints
# `<name>=<exit>` then the hook's stderr, indented; `<name>-gh=<n>` is the number of gh calls it made.
set -euo pipefail
git init -q --bare origin.git
git clone -q origin.git wt 2>/dev/null
cd wt
git config user.email e@e; git config user.name e
mkdir -p lib
echo base > lib/a.txt
git add -A; git commit -qm base; git push -q origin HEAD:main 2>/dev/null
git remote set-head origin main 2>/dev/null || git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
git switch -qc leak; echo '// ported from acme/secret-app' >> lib/a.txt; git commit -qam 'Guard the parser'
git switch -q main; git switch -qc clean; echo three >> lib/a.txt; git commit -qam 'Parse faster, closes #1'
cd ..
mkdir -p stub
cat > stub/gh <<'SH'
#!/usr/bin/env bash
echo "$*" >> "$EVAL_WS/gh.calls"
case "$1 $2" in
  "auth status") exit 0 ;;
  "repo view")
    case "$*" in
      *visibility*) echo "${GH_VIS-PUBLIC}" ;;
      *nameWithOwner*) echo acme/lib ;;
    esac ;;
  "repo list")
    case "$*" in
      *"acme --visibility private"*) echo acme/secret-app ;;
    esac ;;
  "api repos/acme/lib/issues/1") exit 0 ;;
  *) exit 1 ;;
esac
SH
chmod +x stub/gh
cat > check.sh <<'SH'
root=$1; export EVAL_WS=$PWD PATH="$PWD/stub:$PATH" HOME=/Users/dev
printf '%s\n' 'Notes in /Users/dev/GitHub/filed/n.md' 'Ported from acme/secret-app' > wt/body.txt
run() { # name branch cmd [vis]
  git -C wt switch -q "$2"; : > gh.calls
  err=$(jq -n --arg c "$3" --arg d "$PWD/wt" '{session_id:"eval",cwd:$d,hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}' \
    | (cd wt && GH_VIS=${4:-PUBLIC} bash "$root/hooks/checks/disclosure.sh" 2>&1 >/dev/null)); rc=$?
  echo "$1=$rc"; [ -z "$err" ] || sed 's/^/  /' <<<"$err"
  echo "$1-gh=$(grep -c . gh.calls)"
}
run push-leak     leak  'git push origin HEAD:leak'
run push-private  leak  'git push origin HEAD:leak' PRIVATE
run push-clean    clean 'git push origin HEAD:clean'
run pr-home       clean 'gh pr create --title T --body "Reads /Users/dev/GitHub/other/lib/x.dart"'
run pr-ref        clean 'gh pr create --title T --body "Follow-up of #346"'
run pr-file       clean 'gh pr create --title T --body-file body.txt'
run pr-private    clean 'gh pr create --title T --body "Reads /Users/dev/GitHub/other/lib/x.dart"' PRIVATE
run pr-clean      clean 'gh pr create --title T --body "Parses faster, see #1"'
run other-ls      leak  'ls -la lib'
run other-status  leak  'git status --short'
run other-view    leak  'gh pr view 7 --json title'
run other-commit  leak  'git commit -m "mention acme/secret-app"'
echo last=reached
SH
