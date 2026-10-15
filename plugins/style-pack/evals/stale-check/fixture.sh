#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# A fake install layout: the running copy is cache/m/p/0.1.0, the marketplace
# index says 0.2.0 and declares a dependency d@m that is not installed. A stub
# `claude` logs its calls and updates the registry the way the real one does
# (or fails, under FAIL=1). check.sh copies the plugin's hook into the running
# copy and feeds it Stop inputs.
set -euo pipefail
c=home/.claude/plugins/cache/m/p/0.1.0
mkdir -p "$c/hooks" "$c/.claude-plugin" home/.claude/plugins/marketplaces/m/plugins/p/.claude-plugin t bin proj
echo '{"name":"p","version":"0.1.0"}' > "$c/.claude-plugin/plugin.json"
echo '{"name":"p","version":"0.2.0","dependencies":[{"name":"d","marketplace":"m"}]}' \
  > home/.claude/plugins/marketplaces/m/plugins/p/.claude-plugin/plugin.json
cat > bin/claude <<'SH'
#!/usr/bin/env bash
echo "claude $* (in $PWD)" >> "$LOG"
r="$HOME/.claude/plugins/installed_plugins.json"
[ "${FAIL:-}" = 1 ] && { echo "boom: update refused"; exit 1; }
case "$2" in
  install) jq --arg id "$3" --arg p "$PWD" '.plugins[$id] = [{scope:"project",projectPath:$p,version:"1.0.0"}]' "$r" > "$r.n" ;;
  update) jq --arg id "$3" '.plugins[$id][0].version = "0.2.0"' "$r" > "$r.n" ;;
esac
mv "$r.n" "$r"
SH
chmod +x bin/claude
cat > check.sh <<'SH'
h="$PWD/home"; c="$h/.claude/plugins/cache/m/p/0.1.0"; proj="$PWD/proj"
export LOG="$PWD/calls.log"
cp "$1/hooks/stale-check.sh" "$c/hooks/"
reg() { printf '{"plugins":{"p@m":[{"scope":"project","projectPath":"%s","version":"0.1.0"}]}}' "$proj" \
  > "$h/.claude/plugins/installed_plugins.json"; }
run() { printf '{"session_id":"%s","cwd":"%s","stop_hook_active":%s}' "$1" "$proj" "$2" \
  | HOME="$h" TMPDIR="$PWD/t" PATH="$PWD/bin:$PATH" bash "$c/hooks/stale-check.sh"; }
reg; : > "$LOG"
out=$(run s1 false)
echo "shape=$(printf '%s' "$out" | jq -c '[.decision, has("hookSpecificOutput")]')"
printf '%s' "$out" | jq -r .reason
echo "calls:"; sed "s#$PWD#.#g" "$LOG"
echo "registry=$(jq -c '[.plugins["p@m"][0].version, (.plugins["d@m"] != null)]' "$h/.claude/plugins/installed_plugins.json")"
echo "again=[$(run s1 false)]"
echo "active=[$(run s2 true)]"
reg
echo "failed:"; FAIL=1 run s4 false | jq -r .reason | sed "s#$PWD#.#g"
echo '{"name":"p","version":"0.1.0"}' > "$h/.claude/plugins/marketplaces/m/plugins/p/.claude-plugin/plugin.json"
echo "current=[$(run s3 false)]"
SH
