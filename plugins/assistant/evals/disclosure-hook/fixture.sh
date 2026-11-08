#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# wt: branch leak adds a line naming acme/secret-app, branch clean adds a harmless line, both off a pushed main.
# nobase: a repo with no remote branch to compare against.
# stub/gh is repo acme/lib, visibility $GH_VIS (PUBLIC when unset); acme/secret-app is private; only #1 exists;
# GH_BROKEN=1 makes every call fail; every call is appended to gh.calls.
# Test data the hook would catch (a home path, a #<n>) is built at run time, never written out, so
# committing this file does not trip the hook it tests. check.sh feeds hooks/checks/disclosure.sh
# PreToolUse JSON and prints `<name>=<exit>` then the hook's stderr, indented; `<name>-gh=<n>` is the
# number of gh calls it made.
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
git remote set-url origin https://github.com/acme/lib.git
git remote add gl https://gitlab.example.com/acme/lib.git
git update-ref refs/remotes/gl/main main
git remote add work git@github.com-work:acme/lib.git
git remote add upper git@GitHub.COM:acme/lib.git
git remote add short gh:acme/lib
git remote add loc ../origin.git
git remote add glw git@gitlab-work:acme/lib.git
git remote add glp git@gl-proxy:acme/lib.git
git remote add glj git@gl-jump:acme/lib.git
# mirror fetches from gitlab but pushes to gitlab and github.com both.
git remote add mirror https://gitlab.example.com/acme/lib.git
git remote set-url --add --push mirror https://gitlab.example.com/acme/lib.git
git remote set-url --add --push mirror git@github.com:acme/lib.git
cd ..
# wt-default: remote.pushDefault names gl. wt-rewrite: gl is rewritten to github.com.
# wt-sshcmd: core.sshCommand would create ran-conf if anything ran it.
cp -R wt wt-default; git -C wt-default config remote.pushDefault gl
cp -R wt wt-rewrite; git -C wt-rewrite config url.https://github.com/.insteadOf https://gitlab.example.com/
cp -R wt wt-sshcmd; git -C wt-sshcmd config core.sshCommand "touch $PWD/ran-conf; ssh"
# ssh_config maps github.com-work to github.com and gitlab-work, gl-proxy and gl-jump to
# gitlab.example.com, the last two through a proxy. stub/ssh is the real ssh reading only it
# ($SSH_CFG when set), since OpenSSH finds ~/.ssh/config through the password database, not $HOME.
printf '%s\n' 'Host github.com-work' '  HostName github.com' 'Host gitlab-work' '  HostName gitlab.example.com' \
  'Host gl-proxy' '  HostName gitlab.example.com' '  ProxyCommand nc %h %p' \
  'Host gl-jump' '  HostName gitlab.example.com' '  ProxyJump jump.example.com' > ssh_config
git init -q -b main nobase
(cd nobase && git config user.email e@e && git config user.name e && echo x > a.txt && git add -A && git commit -qm base)
# wt-sig: log.showSignature with a gpg.program (an executable, since git runs it without a shell) that would create ran-gpg.
cp -R wt wt-sig; git -C wt-sig config log.showSignature true; printf '#!/bin/sh\ntouch "%s/ran-gpg"\nexit 1\n' "$PWD" > stub-gpg; chmod +x stub-gpg
git -C wt-sig config gpg.program "$PWD/stub-gpg"
# leak is re-made with a gpgsig header, so showSignature would call gpg.program on it.
sigc=$(git -C wt-sig cat-file commit leak | awk 'NR==1,/^$/ { if (/^committer /) { print; print "gpgsig -----BEGIN PGP SIGNATURE-----"; print " "; print " AAAA"; print " -----END PGP SIGNATURE-----"; next } } { print }' | git -C wt-sig hash-object -t commit -w --stdin)
git -C wt-sig update-ref refs/heads/leak "$sigc"
# nobase-up: no base branch; origin's uploadpack would create ran-up if anything contacted it.
cp -R nobase nobase-up; git -C nobase-up remote add origin "$PWD/origin.git"
git -C nobase-up config remote.origin.uploadpack "touch $PWD/ran-up; git-upload-pack"
printf '[core]\n\tsshCommand = ssh\n' > inc.conf
mkdir -p stub
cat > stub/gh <<'SH'
#!/usr/bin/env bash
echo "$*" >> "$EVAL_WS/gh.calls"
[ -z "${GH_BROKEN:-}" ] || exit 1
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
printf '#!/bin/sh\nexec %s -F "${SSH_CFG:-$EVAL_WS/ssh_config}" "$@"\n' "$(command -v ssh)" > stub/ssh
chmod +x stub/ssh
cat > check.sh <<'SH'
root=$1; export EVAL_WS=$PWD PATH="$PWD/stub:$PATH" HOME=$(printf '/%s/dev' Users)
ref=$(printf '#%s' 346); other=$(printf '/%s/other/GitHub/x' Users); mine="$HOME/GitHub/other/lib/x.dart"
printf '%s\n' "Notes in $HOME/GitHub/filed/n.md" 'Ported from acme/secret-app' > wt/body.txt
# run name branch cmd [vis]; DIR= the repo switched to and CWD= where the command runs (both default wt).
run() {
  local d=${DIR:-wt} w=${CWD:-wt}; git -C "$d" switch -q "$2"; : > gh.calls
  err=$(jq -n --arg c "$3" --arg d "$PWD/$w" '{session_id:"eval",cwd:$d,hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}' \
    | (cd "$w" && GH_VIS=${4:-PUBLIC} bash "$root/hooks/checks/disclosure.sh" 2>&1 >/dev/null)); rc=$?
  echo "$1=$rc"; [ -z "$err" ] || sed 's/^/  /' <<<"$err"
  echo "$1-gh=$(grep -c . gh.calls)"
}
run push-leak     leak  'git push origin HEAD:leak'
run push-private  leak  'git push origin HEAD:leak' PRIVATE
run push-clean    clean 'git push origin HEAD:clean'
run pr-home       clean "gh pr create --title T --body \"Reads $mine\""
run pr-ref        clean "gh pr create --title T --body \"Follow-up of $ref\""
run pr-file       clean 'gh pr create --title T --body-file body.txt'
run pr-private    clean "gh pr create --title T --body \"Reads $mine\"" PRIVATE
run pr-clean      clean 'gh pr create --title T --body "Parses faster, see #1"'
run pr-other-home clean "gh pr create --title T --body \"Reads $other\""
run pr-title-flag clean 'gh pr create --title "Handle -F flag" --body "Parses faster"'
run pr-stdin      clean 'gh pr create --title T --body-file -'
run pr-review     clean "gh pr review 5 --comment --body \"Reads $mine\""
run release       clean "gh release create v1 --notes \"Reads $mine\""
run gist          clean "gh gist create --desc \"Reads $mine\" body.txt"
run push-lines    leak  $'git add -A\ngit commit -qm x\ngit push origin HEAD:leak'
run push-chain    leak  'git add -A && git push origin HEAD:leak'
run push-config   leak  'git -c core.x=1 push origin HEAD:leak'
run push-env      leak  'GIT_TRACE=0 git push origin HEAD:leak'
CWD=. run push-cd leak  "cd $PWD/wt && git push origin HEAD:leak"
CWD=. run cd-file clean "cd $PWD/wt && gh pr create --title T --body-file body.txt"
run push-gitlab   leak  'git push gl HEAD:leak'
run pr-sub        clean "url=\$(gh pr create --title T --body \"Reads $mine\")"
run push-sub      leak  'out=$(git push origin HEAD:leak 2>&1)'
run push-tick     leak  'x=`git push origin HEAD:leak`'
run push-mirror   leak  'git push mirror HEAD:leak'
run push-repo-flag leak 'git push --repo=gl origin HEAD:leak'
run push-ssh-alias leak 'git push work HEAD:leak'
run push-ssh-off  leak  'git push glw HEAD:leak'
# A command set for git's ssh is never run, and leaves the host unresolved.
GIT_SSH_COMMAND="touch $PWD/ran-env; ssh" run push-ssh-cmd leak 'git push glw HEAD:leak'
echo "push-ssh-cmd-ran=$([ -e ran-env ] && echo yes || echo no)"
DIR=wt-sshcmd CWD=wt-sshcmd run push-ssh-conf leak 'git push glw HEAD:leak'
echo "push-ssh-conf-ran=$([ -e ran-conf ] && echo yes || echo no)"
run push-ssh-inline leak 'GIT_SSH_COMMAND=ssh git push glw HEAD:leak'
SSH_CFG=/dev/null run push-ssh-noconf leak 'git push work HEAD:leak'
run push-ssh-proxy leak 'git push glp HEAD:leak'
run push-ssh-jump leak  'git push glj HEAD:leak'
# A cd in a subshell ends with it.
run cd-sub        leak  "x=\$(cd $PWD/nowhere); git push origin HEAD:leak"
run cd-tick       leak  "x=\`cd $PWD/nowhere\`; git push origin HEAD:leak"
run cd-paren      leak  "(cd $PWD/nowhere); git push origin HEAD:leak"
CWD=. run cd-paren-in leak "(cd $PWD/wt && git push origin HEAD:leak)"
run push-upper    leak  'git push upper HEAD:leak'
run push-short    leak  'git push short HEAD:leak'
run push-local    leak  'git push loc HEAD:leak'
DIR=wt-default CWD=wt-default run push-default leak 'git push'
DIR=wt-rewrite CWD=wt-rewrite run push-rewrite leak 'git push gl HEAD:leak'
run push-ref      clean 'git push origin leak'
run push-ref-ok   leak  'git push origin clean'
DIR=nobase CWD=nobase run no-base main 'git push origin HEAD:main'
DIR=wt-sig CWD=wt-sig run push-sig leak 'git push origin HEAD:leak'
echo "push-sig-ran=$([ -e ran-gpg ] && echo yes || echo no)"
DIR=nobase-up CWD=nobase-up run no-base-up main 'git push origin HEAD:main'
echo "no-base-up-ran=$([ -e ran-up ] && echo yes || echo no)"
run push-ssh-include leak "git -c include.path=$PWD/inc.conf push glw HEAD:leak"
# the stub fails every call when GH_BROKEN is set
export GH_BROKEN=1
run gh-down       clean 'git push origin HEAD:clean'
run gh-down-pr    clean 'gh pr create --title T --body "Parses faster"'
unset GH_BROKEN
run other-ls      leak  'ls -la lib'
run other-status  leak  'git status --short'
run other-view    leak  'gh pr view 7 --json title'
run other-commit  leak  'git commit -m "mention acme/secret-app"'
echo last=reached
SH
