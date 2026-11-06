#!/usr/bin/env bash
# A throwaway repo: a bare origin.git, a clone wt holding a copy of the plugin-release scripts
# (after-merge.mjs takes its repo root from its own location), an empty home/ for HOME, and
# stub/gh, which answers only `pr view` (an OPEN PR) and fails on anything else.
set -euo pipefail
src=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd)/.claude/skills/plugin-release/scripts
git init -q --bare origin.git
git clone -q origin.git wt 2>/dev/null
mkdir -p home wt/.claude/skills/plugin-release/scripts
cp "$src/after-merge.mjs" "$src/consumers.mjs" wt/.claude/skills/plugin-release/scripts/
cd wt
git config user.email e@e; git config user.name e
git add -A; git commit -qm base; git push -q origin HEAD:main 2>/dev/null
cd ..
mkdir -p stub
cat > stub/gh <<'SH'
#!/usr/bin/env bash
case "$1 $2" in
  "pr view") echo '{"state":"OPEN","mergeCommit":null,"headRefName":"task/x","url":"https://example.test/pr/999999"}' ;;
  *) exit 1 ;;
esac
SH
chmod +x stub/gh
