#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh feeds charon.sh delete commands with a fake `trash` first on PATH and prints each exit code.
# The no-trash branch needs a host without /usr/bin/trash (macOS always has it); there it prints skipped.
set -euo pipefail
cat > check.sh <<'SH'
root=$1; mkdir -p fake
printf '#!/bin/sh\nexit 0\n' > fake/trash; chmod +x fake/trash
hook() { jq -n --arg c "$1" '{tool_input:{command:$c}}' | PATH="$2" bash "$root/hooks/checks/charon.sh" 2>"${3:-/dev/null}"; echo $?; }
T="$PWD/fake:$PATH"
echo "with-rm=$(hook 'rm -rf build' "$T")"
echo "with-sudo=$(hook 'sudo rm x' "$T")"
echo "with-xargs=$(hook 'ls | xargs rm' "$T")"
echo "with-exec=$(hook 'find . -name x -exec rm {} \;' "$T")"
echo "with-trash=$(hook 'trash x' "$T")"
echo "with-git-rm=$(hook 'git rm x' "$T")"
echo "with-rmdir=$(hook 'rmdir x' "$T")"
echo "with-quoted=$(hook 'echo "rm x"' "$T")"
hook 'rm x' "$T" msg.txt >/dev/null
grep -qE "guardrails [·—]" msg.txt && echo "msg-prefix=old" || echo "msg-prefix=clean"
grep -q trash msg.txt && echo "msg-says-trash=yes" || echo "msg-says-trash=no"
if [ -x /usr/bin/trash ]; then echo "notrash=skipped"; else
  bin="$PWD/nobin"; mkdir -p "$bin"
  for t in jq grep cat printf; do ln -sf "$(command -v $t)" "$bin/$t"; done
  echo "notrash-trash=$(hook 'trash x' "$bin")"
  echo "notrash-rm=$(hook 'rm x' "$bin")"
fi
echo done=1
SH
