#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh feeds search-gate.sh disk-wide / home-wide searches and targeted ones
# and prints each exit code. HOME is pinned so the expanded home path is known.
set -euo pipefail
cat > check.sh <<'SH'
root=$1
export HOME=/Users/kai
run() { jq -n --arg c "$2" '{tool_name:"Bash",tool_input:{command:$c}}' | bash "$root/hooks/search-gate.sh" 2>/dev/null; echo "$1=$?"; }
tool() { jq -n --arg t "$2" --argjson i "$3" '{tool_name:$t,tool_input:$i}' | bash "$root/hooks/search-gate.sh" 2>/dev/null; echo "$1=$?"; }
run bad-root      'find / -name "*.plist" 2>/dev/null | head'
run bad-tilde     'cd /tmp && find ~ -type f -name settings.json'
run bad-home      'find $HOME -name "*.log"'
run bad-expanded  'find /Users/kai -iname "*claude*"'
run bad-users     'sudo find /Users -name id_rsa'
run bad-rg        'rg -l TODO ~/'
run bad-grep      'grep -rn "apiKey" / 2>/dev/null'
run bad-grepR     'grep -R foo $HOME'
run bad-fd        'fd -H config /'
run bad-lsR       'ls -laR ~'
run bad-deep      'find ~ -maxdepth 6 -name x'
tool bad-greptool Grep '{"pattern":"foo","path":"/"}'
tool bad-globtool Glob '{"pattern":"/**/*.plist"}'
tool bad-globhome Glob '{"pattern":"**/*.json","path":"~"}'
run ok-project    'find . -name "*.dart" -newer pubspec.yaml'
run ok-subdir     'find ~/.claude/plugins -maxdepth 4 -name plugin.json'
run ok-projpath   'find /Users/kai/proj/lib -name "*.dart"'
run ok-shallow    'find ~ -maxdepth 1 -name ".*rc"'
run ok-fdshallow  'fd -d 2 . ~'
run ok-grepflat   'grep -n foo /etc/hosts'
run ok-rgproject  'rg -n TODO src'
run ok-quoted     'rg -F "/" src'
run ok-ls         'ls -la ~'
run ok-du         'du -sh ~/*'
run ok-message    'git commit -m "guardrails: refuse find / and grep -r ~"'
tool ok-greptool  Grep '{"pattern":"foo","path":"/Users/kai/proj"}'
tool ok-globtool  Glob '{"pattern":"src/**/*.ts"}'
run ok-heredoc    $'git commit -F - <<\'EOF\'\nfind / -name x is refused now\nEOF'
SH
