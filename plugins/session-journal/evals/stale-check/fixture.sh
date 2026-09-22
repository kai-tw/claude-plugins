#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# A fake install layout: the running copy is cache/m/p/0.1.0, the marketplace
# index says 0.2.0. check.sh copies the plugin's hook into the running copy and
# feeds it Stop inputs.
set -euo pipefail
c=home/.claude/plugins/cache/m/p/0.1.0
mkdir -p "$c/hooks" "$c/.claude-plugin" home/.claude/plugins/marketplaces/m/plugins/p/.claude-plugin t
echo '{"name":"p","version":"0.1.0"}' > "$c/.claude-plugin/plugin.json"
echo '{"name":"p","version":"0.2.0"}' > home/.claude/plugins/marketplaces/m/plugins/p/.claude-plugin/plugin.json
cat > check.sh <<'SH'
h="$PWD/home"; c="$h/.claude/plugins/cache/m/p/0.1.0"
cp "$1/hooks/stale-check.sh" "$c/hooks/"
run() { printf '{"session_id":"%s","cwd":"/proj","stop_hook_active":%s}' "$1" "$2" \
  | HOME="$h" TMPDIR="$PWD/t" bash "$c/hooks/stale-check.sh"; }
out=$(run s1 false)
echo "shape=$(printf '%s' "$out" | jq -c '[.decision, has("hookSpecificOutput")]')"
printf '%s' "$out" | jq -r .reason
echo "again=[$(run s1 false)]"
echo "active=[$(run s2 true)]"
echo '{"name":"p","version":"0.1.0"}' > "$h/.claude/plugins/marketplaces/m/plugins/p/.claude-plugin/plugin.json"
echo "current=[$(run s3 false)]"
SH
