#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# One clone of a local bare remote on task/a (PR 7), pushed. stub/gh's `webhook
# forward` fails the way gh-webhook does: an `Error:` line, then its usage text.
set -euo pipefail
git init -q --bare origin.git
git clone -q origin.git wa 2>/dev/null
(
  cd wa
  git config user.email e@e; git config user.name e
  mkdir -p .claude .github/workflows
  printf 'vcs: git\n' > .claude/assistant.md
  printf '.claude/.assistant/\n' > .gitignore
  printf 'on: pull_request\n' > .github/workflows/ci.yml
  git add -A; git commit -qm base
  git switch -qc task/a
  echo a > note.txt; git add -A; git commit -qm "task: a"
  git push -q -u origin HEAD 2>/dev/null
)
mkdir -p stub
cat > stub/gh <<'SH'
#!/usr/bin/env bash
case "$1 $2" in
  "auth status") exit 0 ;;
  "repo view") case "$*" in *nameWithOwner*) echo o/r ;; esac ;;
  "pr view")
    case "$*" in
      *isDraft*) echo "7 true main" ;;
      *number*) echo 7 ;;
      *) echo "https://github.com/o/r/pull/7" ;;
    esac ;;
  "pr checks") echo "pending ci" ;;
  "webhook forward")
    cat >&2 <<'TXT'
Error: websocket: bad handshake
Usage:
  forward --events=<types> [--url=<url>] [flags]

Flags:
  -S, --secret string        Webhook secret for incoming events
  -U, --url string           Address of the local server to receive events. If omitted, events will be printed to stdout.
TXT
    exit 1 ;;
  *) exit 1 ;;
esac
SH
chmod +x stub/gh
