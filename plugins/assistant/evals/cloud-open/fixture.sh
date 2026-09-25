#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# fake/claude stands in for the CLI: it records its arguments one per line in
# $ARGS and prints what `claude --cloud` prints — or, with FAKE_FAIL set, a
# refusal. solo/ has no remote (a bundle upload, nothing to push); ahead/ has an
# upstream it is one commit ahead of.
set -euo pipefail
g() { git -c user.name=e -c user.email=e@e "$@"; }
mkdir -p fake
cat > fake/claude <<'CLAUDE'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$ARGS"
if [ -n "${FAKE_FAIL:-}" ]; then echo "Cloud sessions are not available for this account."; exit 1; fi
printf '\033[?25lCreated cloud session: Probe\r\nView: https://claude.ai/code/session_01FAKEid?from=cli&m=0\r\nResume with: claude --teleport session_01FAKEid\r\n\033[?25h'
CLAUDE
chmod +x fake/claude
mkdir solo && (cd solo && git init -q && touch a && g add -A && g commit -qm init)
git init -q --bare up.git
git clone -q up.git ahead 2>/dev/null
(cd ahead && touch a && g add -A && g commit -qm one && g push -q origin HEAD 2>/dev/null \
  && git branch -q -u "origin/$(git branch --show-current)" && touch b && g add -A && g commit -qm two)
