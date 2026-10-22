#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# Two clones of a local bare remote, wa on task/a (PR 7) and wb on task/b (PR 8),
# both pushed. stub/gh answers per branch: a PR's checks come from checks.<branch>
# ("<bucket> <name>" lines). Its `webhook forward` behaves like GitHub's: one at a
# time (a second gets HTTP 422 until the first stops), and it prints each line
# appended to gh.events. Every start is logged to fwd.log.
set -euo pipefail
git init -q --bare origin.git
for b in a b; do
  git clone -q origin.git "w$b" 2>/dev/null
  (
    cd "w$b"
    git config user.email e@e; git config user.name e
    mkdir -p .claude .github/workflows
    printf 'vcs: git\n' > .claude/assistant.md
    printf '.claude/.assistant/\n' > .gitignore
    printf 'on: pull_request\n' > .github/workflows/ci.yml
    git add -A; git commit -qm base
    git switch -qc "task/$b"
    echo "$b" > note.txt; git add -A; git commit -qm "task: $b"
    git push -q -u origin HEAD 2>/dev/null
  )
done
touch gh.events
mkdir -p stub
cat > stub/gh <<'SH'
#!/usr/bin/env bash
b=$(git symbolic-ref --short HEAD 2>/dev/null)
num() { case "$b" in task/a) echo 7 ;; task/b) echo 8 ;; *) echo 9 ;; esac; }
case "$1 $2" in
  "auth status") exit 0 ;;
  "repo view") case "$*" in *nameWithOwner*) echo o/r ;; esac ;;
  "pr view")
    case "$*" in
      *isDraft*) echo "$(num) true main" ;;
      *number*) num ;;
      *) echo "https://github.com/o/r/pull/$(num)" ;;
    esac ;;
  "pr checks")
    # lag.<branch> holds how many more reads still say running, as GitHub's API does
    # for a moment after a suite's completed event.
    lag="$EVAL_WS/lag.${b//\//_}"; n=$(cat "$lag" 2>/dev/null || echo 0)
    if [ "$n" -gt 0 ]; then echo $((n - 1)) > "$lag"; echo "pending ci"; exit 0; fi
    cat "$EVAL_WS/checks.${b//\//_}" ;;
  "webhook forward")
    hook="$EVAL_WS/hook"
    if ! (set -o noclobber; echo $$ > "$hook") 2>/dev/null; then
      echo "422" >> "$EVAL_WS/fwd.log"
      echo "Error: error creating webhook: HTTP 422: Validation Failed" >&2
      echo "Hook already exists on this repository" >&2; exit 1
    fi
    echo "start" >> "$EVAL_WS/fwd.log"
    tail -n0 -f "$EVAL_WS/gh.events" & t=$!
    trap 'kill $t 2>/dev/null; rm -f "$hook"; exit 0' TERM INT
    echo "Forwarding Webhook events from GitHub..." >&2
    wait ;;
  *) exit 1 ;;
esac
SH
chmod +x stub/gh
# up <pr>… — wait until each PR's watcher is registered and a forwarder has connected.
cat > up <<'SH'
#!/usr/bin/env bash
d=cache/asst-pr/o__r
for _ in $(seq 100); do
  ok=1; for n in "$@"; do [ -f $d/watch-$n.pid ] || ok=0; done
  [ $ok = 1 ] && grep -q connected $d/events.jsonl 2>/dev/null && exit 0
  sleep 0.1
done
exit 1
SH
chmod +x up
