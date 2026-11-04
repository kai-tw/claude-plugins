#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# origin.git is a local bare remote with main and staging, staging one commit
# ahead; wt is a clone whose project config sends task PRs into staging and which has a
# release.yml. stub/gh logs every call to gh.log, finds run 4242 for any release,
# and reads that run's "<status> <conclusion> <url>" from run.state. Its `webhook
# forward` prints each line appended to gh.events; while drop.once exists, a
# forwarder connects, then drops the way GitHub's did (websocket close 1006).
# Every forwarder start is logged to fwd.log.
set -euo pipefail
git init -q --bare origin.git
git clone -q origin.git wt 2>/dev/null
cd wt
git config user.email e@e; git config user.name e
mkdir -p .claude .github/workflows
printf 'vcs: git\nbase_branch: staging\n' > .claude/assistant.md
printf '.claude/.assistant/\n' > .gitignore
printf 'on: workflow_dispatch\n' > .github/workflows/release.yml
git add -A; git commit -qm base; git push -q origin HEAD:main 2>/dev/null
git remote set-head origin main 2>/dev/null || git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
git switch -qc staging
echo feature > feature.txt
git add -A; git commit -qm 'staging: add a feature'
git push -q -u origin HEAD 2>/dev/null
cd ..
touch gh.events
mkdir -p stub
cat > stub/gh <<'SH'
#!/usr/bin/env bash
echo "gh $*" >> "$EVAL_WS/gh.log"
case "$1 $2" in
  "auth status") exit 0 ;;
  "repo view") case "$*" in *nameWithOwner*) echo o/r ;; esac ;;
  "workflow run") exit 0 ;;
  "run list") echo 4242 ;;
  "run view") cat "$EVAL_WS/run.state" ;;
  "webhook forward")
    echo "start" >> "$EVAL_WS/fwd.log"
    if [ -f "$EVAL_WS/drop.once" ]; then
      mv "$EVAL_WS/drop.once" "$EVAL_WS/dropped"
      echo "Forwarding Webhook events from GitHub..." >&2
      sleep 0.3
      echo "Error: error receiving json event: websocket: close 1006 (abnormal closure): unexpected EOF" >&2
      exit 1
    fi
    tail -n0 -f "$EVAL_WS/gh.events" & t=$!
    trap 'kill $t 2>/dev/null; exit 0' TERM INT
    echo "Forwarding Webhook events from GitHub..." >&2
    wait ;;
  *) exit 1 ;;
esac
SH
chmod +x stub/gh
# state <status> [<conclusion>] — what `gh run view` says of run 4242.
cat > state <<'SH'
#!/usr/bin/env bash
echo "$1 ${2:-} https://github.com/o/r/actions/runs/4242" > "$EVAL_WS/run.state"
SH
# finish <conclusion> — run 4242 completes, and GitHub sends its event.
cat > finish <<'SH'
#!/usr/bin/env bash
"$EVAL_WS/state" completed "$1"
echo '{"action":"completed","workflow_run":{"id":4242}}' >> "$EVAL_WS/gh.events"
SH
# connected <n> — wait until forwarders have connected n times in all.
cat > connected <<'SH'
#!/usr/bin/env bash
f=cache/gh-webhook-hub/o__r/workflow_run/events.jsonl
for _ in $(seq 200); do
  [ "$(grep -c connected "$f" 2>/dev/null || echo 0)" -ge "$1" ] && exit 0
  sleep 0.1
done
exit 1
SH
chmod +x state finish connected
