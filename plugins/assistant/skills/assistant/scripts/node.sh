#!/usr/bin/env bash
# Sourced by the launchers that run a .mjs script. A shell whose nvm default
# points at a deleted version has no node on PATH, and the agent then falls back
# to doing the script's job by hand — so look where Node is usually installed
# before giving up, and say where we looked when it isn't anywhere.

# Prints the path of a node that runs; exit 1 when there is none.
asst_node() {
  local n
  n=$(command -v node 2>/dev/null) && "$n" --version >/dev/null 2>&1 && { printf '%s\n' "$n"; return 0; }
  for n in $(ls -d "$HOME"/.nvm/versions/node/v*/bin/node 2>/dev/null | sort -rV) \
           /opt/homebrew/bin/node /usr/local/bin/node "$HOME/.volta/bin/node"; do
    [ -x "$n" ] && "$n" --version >/dev/null 2>&1 && { printf '%s\n' "$n"; return 0; }
  done
  return 1
}

# exec node "$@", or stop with exit 2 and the places searched.
exec_node() {
  local n
  n=$(asst_node) || {
    echo "$(basename "$0"): node not found — not on PATH, nor in ~/.nvm/versions/node, /opt/homebrew/bin, /usr/local/bin or ~/.volta/bin. Install Node or put it on PATH; don't do this command's job by hand." >&2
    exit 2
  }
  exec "$n" "$@"
}
