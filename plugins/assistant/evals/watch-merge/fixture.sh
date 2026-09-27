#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# wt is on branch t7, whose PR is acme/lib#7 (state $GH_STATE, OPEN when unset).
# stub/gh's `webhook forward` says it is connected, prints events.jsonl as the
# pushed events (the case copies in merge / closed / none.jsonl), then holds the
# connection until killed — or, with
# GH_HOOK_TAKEN=yes, fails as when another forwarder holds the repo.
# GH_NOWEBHOOK=yes means the extension is not installed.
set -euo pipefail
git init -q wt
cd wt
git config user.email e@e; git config user.name e
git commit -q --allow-empty -m base
git switch -qc t7
cd ..
ev() { printf '{"action":"%s","number":%s,"pull_request":{"merged":%s},"repository":{"full_name":"acme/lib"}}\n' "$@"; }
{ ev closed 8 true; ev synchronize 7 false; ev closed 7 true; } > merge.jsonl
ev closed 7 false > closed.jsonl
: > none.jsonl
mkdir -p stub
cat > stub/gh <<'SH'
#!/usr/bin/env bash
case "$1 $2" in
  "webhook --help") [ "${GH_NOWEBHOOK:-}" = yes ] && exit 1; exit 0 ;;
  "webhook forward")
    [ "${GH_NOWEBHOOK:-}" = yes ] && exit 1
    if [ "${GH_HOOK_TAKEN:-}" = yes ]; then
      echo "Error: error creating webhook: HTTP 422: Validation Failed" >&2
      echo "Hook already exists on this repository" >&2; exit 1
    fi
    echo "Forwarding Webhook events from GitHub..." >&2
    sleep 0.5; cat "$EVAL_WS/events.jsonl"
    trap 'kill $s; exit 0' TERM
    sleep 30 >/dev/null 2>&1 & s=$!; wait $s ;;
  "pr view")
    case "$*" in
      *"--json state"*) echo "${GH_STATE:-OPEN}" ;;
      *) echo "acme/lib#7" ;;
    esac ;;
  *) exit 1 ;;
esac
SH
chmod +x stub/gh
