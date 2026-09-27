#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh feeds babel.sh whole-disk / whole-home searches and single-shelf ones
# and prints each exit code. HOME and the session cwd are pinned.
set -euo pipefail
cat > check.sh <<'SH'
root=$1
export HOME=/Users/kai
run() { jq -n --arg c "$2" --arg d "${3:-/Users/kai/proj}" '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}' | bash "$root/hooks/babel.sh" 2>/dev/null; echo "$1=$?"; }
tool() { jq -n --arg t "$2" --argjson i "$3" '{tool_name:$t,cwd:"/Users/kai/proj",tool_input:$i}' | bash "$root/hooks/babel.sh" 2>/dev/null; echo "$1=$?"; }
run bad-root      'find / -name "*.plist" 2>/dev/null | head'
run bad-tilde     'cd /tmp && find ~ -type f -name settings.json'
run bad-qhome     'find "$HOME" -name x'
run bad-qroot     "find '/' -name x"
run bad-expanded  'find /Users/kai -iname "*claude*"'
run bad-users     'sudo find /Users -name id_rsa'
run bad-cdhome    'cd ~ && find . -name x'
run bad-cdroot    'cd / && rg foo'
run bad-cwdhome   'rg -n TODO' /Users/kai
run bad-dotdot    'find .. -name x'
run bad-rg        'rg -l TODO ~/'
run bad-grep      'grep -rn "apiKey" / 2>/dev/null'
run bad-greprr    'grep -R foo $HOME'
run bad-fd        'fd -H config /'
run bad-fdext     'fd -e plist . ~'
run bad-lsr       'ls -laR ~'
run bad-tree      'tree ~'
run bad-volumes   'find /Volumes -name x'
run bad-deep      'find ~ -maxdepth 6 -name x'
run bad-agdeep    'ag --depth 5 foo ~'
run bad-xargs     'echo x | xargs grep -r foo /'
tool bad-greptool Grep '{"pattern":"foo","path":"/"}'
tool bad-globabs  Glob '{"pattern":"/**/*.plist"}'
tool bad-globhome Glob '{"pattern":"**/*.json","path":"/Users/kai"}'
tool bad-globtilde Glob '{"pattern":"~/**/*.json"}'
run ok-project    'find . -name "*.dart" -newer pubspec.yaml'
run ok-subdir     'find ~/.claude/plugins -maxdepth 4 -name plugin.json'
run ok-projpath   'find /Users/kai/proj/lib -name "*.dart"'
run ok-shallow    'find ~ -maxdepth 1 -name ".*rc"'
run ok-fdshallow  'fd -d 2 . ~'
run ok-agshallow  'ag --depth 1 foo ~'
run ok-treeshallow 'tree -L 2 ~'
run ok-grepflat   'grep -n foo /etc/hosts'
run ok-grepnorec  'grep foo ~/.zshrc'
run ok-rgproject  'rg -n TODO src'
run ok-rgslash    'rg -e / src'
run ok-rgquoted   'rg -F "/" src'
run ok-fdext      'fd -e md . docs'
run ok-ls         'ls -la ~'
run ok-du         'du -sh ~/*'
run ok-cdproj     'cd ~/proj && find . -name x'
run ok-cwdproj    'rg -n TODO'
run ok-message    'git commit -m "guardrails: refuse find / and grep -r ~"'
tool ok-greptool  Grep '{"pattern":"foo","path":"/Users/kai/proj"}'
tool ok-globshallow Glob '{"pattern":"*.md","path":"/Users/kai"}'
tool ok-globproj  Glob '{"pattern":"src/**/*.ts"}'
tool ok-globabsproj Glob '{"pattern":"/Users/kai/proj/**/*.ts"}'
run ok-heredoc    $'git commit -F - <<\'EOF\'\nfind / -name x is refused now\nEOF'
SH
