#!/usr/bin/env bash
# search-gate.sh — PreToolUse(Bash|Glob|Grep): refuse a recursive search rooted
# at the whole disk or the whole home directory. `find / -name …` walks every
# mounted volume, the system tree and every project's node_modules / build
# output, for minutes, to answer a question one known directory, `command -v`
# or the Spotlight index answers at once — and the agent sits blocked on it.
#
# Roots: `/`, `~`, `$HOME` (and its expanded path), `/Users`, `/home`. A
# directory under them (`~/.claude`, `/Users/me/proj`) is targeted, not wide,
# and passes; so does a depth limit of 2 or less (`find ~ -maxdepth 1`).
# Searchers: find, fd, rg, ag, `grep -r`, `ls -R`; the Glob and Grep tools by
# their `path` or an absolute Glob `pattern`.
#
# WHAT IT DOES NOT SEE
#   Quoted strings and heredoc bodies are dropped before matching, so a pattern
#   or a message that mentions `/` passes — and so does a search hidden in
#   `bash -c '…'` or a script file.

set -uo pipefail
[ "${GUARDRAILS:-on}" = "off" ] && exit 0

payload="$(cat 2>/dev/null)"
tool="$(printf '%s' "$payload" | jq -r '.tool_name // "Bash"' 2>/dev/null || true)"
home="${HOME%/}"

wide() {  # wide <path> — is it one of the roots?
  local p="$1"
  [ "$p" = / ] && return 0
  p="${p%/}"; p="${p%/\*}"; p="${p%/\*\*}"
  case "$p" in
    ''|'~'|'$HOME'|'${HOME}'|/Users|/home) return 0 ;;
  esac
  [ -n "$home" ] && [ "$p" = "$home" ]
}

deny() {
  # exit 2, not a JSON deny: only exit 2 is documented to take precedence over a
  # `permissions.allow` rule. The reason goes to stderr, which is what Claude is shown.
  cat >&2 <<MSG
🛡️ guardrails — no disk-wide or home-wide search: \`$1\` walks every volume, system tree and project build output, for minutes.

Search where the thing lives instead: the project (\`.\`), or the one directory it belongs in (\`~/.claude\`, \`~/Library/Application Support/<app>\`, \`/opt/homebrew\`, …). A binary: \`command -v\` / \`type -a\`. A file by name on macOS: \`mdfind -name <name>\` (the Spotlight index, instant). To look at the top of a tree, cap the depth: \`find ~ -maxdepth 2 …\`.
MSG
  exit 2
}

case "$tool" in
  Glob|Grep)
    path="$(printf '%s' "$payload" | jq -r '.tool_input.path // empty' 2>/dev/null || true)"
    [ -n "$path" ] && wide "$path" && deny "$tool path=$path"
    if [ "$tool" = Glob ]; then
      pat="$(printf '%s' "$payload" | jq -r '.tool_input.pattern // empty' 2>/dev/null || true)"
      case "$pat" in
        */\*\**) wide "${pat%%/\*\**}/" && deny "Glob pattern=$pat" ;;
      esac
    fi
    exit 0 ;;
  Bash) ;;
  *) exit 0 ;;
esac

cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[ -z "$cmd" ] && exit 0

# Everything after the first `<<` line is a heredoc body; then drop quoted text
# and split into simple commands.
bare="$(printf '%s\n' "$cmd" | awk '{print} /<</{exit}' | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")"
segments="$(printf '%s\n' "$bare" | sed -E 's/(\|\||&&|[;&|()])/\n/g')"

while IFS= read -r seg; do
  read -ra w <<<"$seg" || true
  i=0
  # Skip wrappers and VAR=value prefixes to reach the command itself.
  while [ $i -lt ${#w[@]} ]; do
    case "${w[$i]}" in
      sudo|command|time|nice|env|xargs|*=*) i=$((i + 1)) ;;
      *) break ;;
    esac
  done
  [ $i -lt ${#w[@]} ] || continue
  prog="${w[$i]##*/}"
  args=("${w[@]:$((i + 1))}")

  searches=0 depth=''
  case "$prog" in
    find|gfind|fd|fdfind|rg|ag) searches=1 ;;
    grep|ggrep|egrep|fgrep)
      for a in "${args[@]}"; do
        case "$a" in --recursive|--dereference-recursive) searches=1 ;; --*) ;; -*[rR]*) searches=1 ;; esac
      done ;;
    ls|gls)
      for a in "${args[@]}"; do
        case "$a" in --recursive) searches=1 ;; --*) ;; -*R*) searches=1 ;; esac
      done ;;
  esac
  [ $searches = 1 ] || continue

  hit=''
  for ((j = 0; j < ${#args[@]}; j++)); do
    a="${args[$j]}"
    case "$a" in
      -maxdepth|--max-depth|-d|--exact-depth) depth="${args[$((j + 1))]:-}" ;;
      --max-depth=*|--exact-depth=*) depth="${a#*=}" ;;
    esac
    wide "$a" && hit="$a"
  done
  [ -n "$hit" ] || continue
  case "$depth" in [0-2]) continue ;; esac
  deny "$prog … $hit"
done <<<"$segments"
exit 0
