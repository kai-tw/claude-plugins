#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# fake/claude stands in for the CLI: it records its arguments one per line in
# $ARGS and prints what `claude --cloud` prints — or, with FAKE_FAIL set, a
# refusal; it echoes --name back as the title. Into --debug-file it writes the
# account's environments and the one picked: --settings' defaultEnvironmentId
# when it is in the list, else Default, as claude falls back; with FAKE_NOPICK
# set it leaves out the pick. fake/gh answers `pr view` with
# $FAKE_PR, or fails like a branch with no PR. solo/ has no remote (a bundle
# upload, nothing to push); ahead/ has an upstream it is one commit ahead of.
set -euo pipefail
g() { git -c user.name=e -c user.email=e@e "$@"; }
mkdir -p fake
cat > fake/claude <<'CLAUDE'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$ARGS"
if [ -n "${FAKE_FAIL:-}" ]; then echo "Cloud sessions are not available for this account."; exit 1; fi
name=Probe dbg=/dev/null want=""
while [ $# -gt 0 ]; do
  case "$1" in
    --name) name=$2 ;;
    --debug-file) dbg=$2 ;;
    --settings) want=$(sed -n 's/.*"defaultEnvironmentId":"\([^"]*\)".*/\1/p' <<<"$2") ;;
  esac
  shift
done
case "$want" in env_01Flutter) picked="env_01Flutter (Flutter, anthropic_cloud)" ;; *) picked="env_01Default (Default, anthropic_cloud)" ;; esac
printf '2026-10-02T13:40:00.000Z [DEBUG] Available environments: env_01Default (Default, anthropic_cloud), env_01Flutter (Flutter, anthropic_cloud), ccpool_01Box (Build box, byoc)\n' > "$dbg"
[ -n "${FAKE_NOPICK:-}" ] || printf '2026-10-02T13:40:00.100Z [DEBUG] Selected environment: %s\n' "$picked" >> "$dbg"
printf '\033[?25lCreated cloud session: %s\r\n' "$name"
printf 'View: https://claude.ai/code/session_01FAKEid?from=cli&m=0\r\nResume with: claude --teleport session_01FAKEid\r\n\033[?25h'
CLAUDE
cat > fake/gh <<'GH'
#!/usr/bin/env bash
[ "$1 $2" = "pr view" ] && [ -n "${FAKE_PR:-}" ] && { echo "$FAKE_PR"; exit 0; }
echo "no pull requests found" >&2; exit 1
GH
chmod +x fake/claude fake/gh
mkdir solo && (cd solo && git init -q -b main && touch a && g add -A && g commit -qm init)
mkdir -p solo/.claude/assistant/cloud-profiles
printf -- '---\nmodel: sonnet\neffort: low\nenvironment: Flutter\ncheck_every: none\n---\n' > solo/.claude/assistant/cloud-profiles/flutter.md
git init -q --bare up.git
git clone -q up.git ahead 2>/dev/null
(cd ahead && touch a && g add -A && g commit -qm one && g push -q origin HEAD 2>/dev/null \
  && git branch -q -u "origin/$(git branch --show-current)" && touch b && g add -A && g commit -qm two)
