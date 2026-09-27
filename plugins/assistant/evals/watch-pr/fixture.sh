#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# wt is on branch t7, whose PR is acme/lib#7 (state $GH_STATE, OPEN when unset;
# CI state in the file `checks`: pending · passed · failed).
# stub/gh's `webhook forward` says it is connected, then after a second copies
# checks.after (if any) over checks — CI finishing — and prints events.jsonl as
# the pushed events (the case copies in one of the *.jsonl below); then it holds
# the connection until killed. GH_EARLY=yes finishes CI before it says it is
# connected; GH_HOOK_TAKEN=yes fails as when another forwarder holds the repo;
# GH_NOWEBHOOK=yes means the extension is not installed.
set -euo pipefail
git init -q wt
cd wt
git config user.email e@e; git config user.name e
git commit -q --allow-empty -m base
git switch -qc t7
cd ..
ev() { printf '{"action":"%s","number":%s,"pull_request":{"merged":%s},"repository":{"full_name":"acme/lib"}}\n' "$@"; }
suite() { printf '{"action":"%s","check_suite":{"head_branch":"%s"},"repository":{"full_name":"acme/lib"}}\n' "$@"; }
{ ev closed 8 true; ev synchronize 7 false; ev closed 7 true; } > merge.jsonl
ev closed 7 false > closed.jsonl
{ suite requested t7; suite completed t9; suite completed t7; } > suite.jsonl
: > none.jsonl
echo passed > checks
mkdir -p stub
cat > stub/gh <<'SH'
#!/usr/bin/env bash
finish() { [ -f "$EVAL_WS/checks.after" ] && cp "$EVAL_WS/checks.after" "$EVAL_WS/checks"; }
case "$1 $2" in
  "webhook --help") [ "${GH_NOWEBHOOK:-}" = yes ] && exit 1; exit 0 ;;
  "webhook forward")
    [ "${GH_NOWEBHOOK:-}" = yes ] && exit 1
    if [ "${GH_HOOK_TAKEN:-}" = yes ]; then
      echo "Error: error creating webhook: HTTP 422: Validation Failed" >&2
      echo "Hook already exists on this repository" >&2; exit 1
    fi
    [ "${GH_EARLY:-}" = yes ] && finish
    echo "Forwarding Webhook events from GitHub..." >&2
    sleep 1; finish; cat "$EVAL_WS/events.jsonl"
    trap 'kill $s; exit 0' TERM
    sleep 30 >/dev/null 2>&1 & s=$!; wait $s ;;
  "pr view")
    case "$*" in
      *"--json state"*) echo "${GH_STATE:-OPEN}" ;;
      *) echo "acme/lib#7" ;;
    esac ;;
  "pr checks") cat "$EVAL_WS/checks" ;;
  *) exit 1 ;;
esac
SH
chmod +x stub/gh
