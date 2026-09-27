#!/usr/bin/env bash
# babel.sh — PreToolUse(Bash|Glob|Grep): refuse a recursive search rooted at the
# whole disk or the whole home directory.
#
# Borges' Library of Babel holds every book and no catalogue; its librarians
# walk the hexagons for a lifetime and die before finding the one they want.
# `find / -name …` is that walk: every volume, the system tree and every
# project's build output, for minutes, while the agent waits — to answer what
# one known directory, `command -v` or the Spotlight index answers at once.
# Nothing breaks, so a warning is read past; hence a refusal, and one that names
# the catalogue to use instead.
#
# Roots: `/`, `~`, `$HOME` and its expanded path, `/Users`, `/home`, `/Volumes`,
# `/System/Volumes/Data` — also as `.` after a `cd` to one of them in the same
# command, or when the session's cwd is one. A directory below them
# (`~/.claude`, `/Users/me/proj`) is a single shelf and passes; so does a depth
# of 2 or less. Searchers: find, fd, rg, ag, `grep -r`, `ls -R`, tree; the Grep
# tool, and the Glob tool when its pattern holds `**`.
#
# WHAT IT DOES NOT SEE
#   A search inside `bash -c '…'`, a script file or a heredoc body.

set -uo pipefail
set -f   # paths such as `~/*` are data here, never globs to expand
[ "${GUARDRAILS:-on}" = "off" ] && exit 0

payload="$(cat 2>/dev/null)"
field() { printf '%s' "$payload" | jq -r "$1 // empty" 2>/dev/null || true; }
tool="$(field .tool_name)"; tool="${tool:-Bash}"
cwd="$(field .cwd)"; cwd="${cwd:-$PWD}"
home="${HOME%/}"

# wide <path> — is it one of the roots? Relative paths resolve against $dir.
wide() {
  local p="$1" out='' part
  case "$p" in
    /*|'~'|'~/'*|'$HOME'*|'${HOME}'*) ;;
    *) p="$dir/$p" ;;
  esac
  # Collapse `.`, `..`, `//`, a trailing `/` or `/*`, so `~/proj/..` is `~`.
  local IFS=/
  for part in $p; do
    case "$part" in
      ''|.|'*') ;;
      ..) out="${out%/*}" ;;
      *) out="$out/$part" ;;
    esac
  done
  out="${out#/}"
  case "$out" in
    ''|'~'|'$HOME'|'${HOME}'|Users|home|Volumes|System/Volumes/Data) return 0 ;;
  esac
  [ -n "$home" ] && [ "/$out" = "$home" ]
}

deny() {
  # exit 2, not a JSON deny: only exit 2 is documented to take precedence over a
  # `permissions.allow` rule. The reason goes to stderr, which is what Claude is shown.
  cat >&2 <<MSG
🛡️ guardrails · babel — \`$1\` walks the Library of Babel: every volume, system tree and build output, shelf by shelf, for minutes.

Go to the shelf the thing belongs on: the project (\`.\`), or its one directory (\`~/.claude\`, \`~/Library/Application Support/<app>\`, \`/opt/homebrew\`, …). A binary: \`command -v\` / \`type -a\`. A file by name on macOS: \`mdfind -name <name>\`, the Spotlight catalogue, instant. To glance at the top of a tree, cap the depth at 2. Not found where it should be? Doubt the name before widening the search.
If the user asked in so many words for a whole-disk search, give them the command to run themselves.
MSG
  exit 2
}

shallow() { case "${1:-}" in [0-2]) return 0 ;; esac; return 1; }

case "$tool" in
  Grep|Glob)
    dir="$cwd"
    path="$(field .tool_input.path)"; path="${path:-.}"
    if [ "$tool" = Grep ]; then
      wide "$path" && deny "Grep path=$path"
    else
      pat="$(field .tool_input.pattern)"
      case "$pat" in
        *'**'*) base="${pat%%\*\**}"
                case "$base" in /*|'~'*) ;; *) base="$path/$base" ;; esac
                wide "${base:-/}" && deny "Glob $pat in $path" ;;
      esac
    fi
    exit 0 ;;
  Bash) ;;
  *) exit 0 ;;
esac

cmd="$(field .tool_input.command)"
[ -z "$cmd" ] && exit 0
# Everything after the first `<<` line is a heredoc body.
cmd="$(printf '%s\n' "$cmd" | awk '{print} /<</{exit}')"

# Split into words the way the shell would — quotes removed, so `find "$HOME"`
# reads as `$HOME` — one per line, with an empty line between simple commands.
words="$(printf '%s' "$cmd" | awk '
  function emit() { if (have) print tok; tok = ""; have = 0 }
  {
    s = $0 "\n"; n = length(s)
    for (i = 1; i <= n; i++) {
      c = substr(s, i, 1)
      if (q != "") { if (c == q) q = ""; else tok = tok c; continue }
      if (c == "\047" || c == "\"") { q = c; have = 1 }
      else if (c == "\\") { i++; tok = tok substr(s, i, 1); have = 1 }
      else if (c == " " || c == "\t") emit()
      else if (index(";&|()\n", c)) { emit(); print "" }
      else { tok = tok c; have = 1 }
    }
  }')"

# check <prog> <args…> — deny when the search is rooted at a root and not capped.
check() {
  local prog="${1##*/}" a v depth='' pattern=1 paths=() recursive=0 i=0
  shift
  local args=("$@") n=$#
  # Options that take a value, per tool; their value is never a path or the pattern.
  local takes=''
  case "$prog" in
    find|gfind)
      while [ $i -lt $n ]; do
        a="${args[$i]}"
        case "$a" in -H|-L|-P|-O*) ;; -D) i=$((i + 1)) ;; *) break ;; esac
        i=$((i + 1))
      done
      while [ $i -lt $n ]; do
        case "${args[$i]}" in -*|'('|'!') break ;; esac
        paths+=("${args[$i]}"); i=$((i + 1))
      done
      while [ $i -lt $n ]; do
        [ "${args[$i]}" = -maxdepth ] && depth="${args[$((i + 1))]:-}"
        i=$((i + 1))
      done
      [ ${#paths[@]} -gt 0 ] || paths=(.)
      recursive=1 ;;
    fd|fdfind) takes='-d --max-depth --exact-depth -e --extension -t --type -E --exclude -c --color -j --threads -S --size --changed-within --changed-before -o --owner --base-directory --max-results'; recursive=1 ;;
    rg)        takes='-d --max-depth -g --glob --iglob -t --type -T --type-not -m --max-count -A -B -C --context -M --max-columns --max-filesize -r --replace -E --encoding --type-add --pre --sort --sortr --color --colors -j --threads'; recursive=1 ;;
    ag)        takes='--depth -G --file-search-regex --ignore -m --max-count -A -B -C --context --path-to-ignore'; recursive=1 ;;
    grep|ggrep|egrep|fgrep) takes='-m --max-count -A -B -C --context -d --directories -D --devices --include --exclude --exclude-dir --label' ;;
    ls|gls)    pattern=0 ;;
    tree)      takes='-L -P -I -o --filelimit'; pattern=0; recursive=1 ;;
    *) return 0 ;;
  esac

  if [ -n "$takes" ] || [ "$prog" = ls ] || [ "$prog" = gls ]; then
    while [ $i -lt $n ]; do
      a="${args[$i]}"; v="${args[$((i + 1))]:-}"
      case "$a" in
        --) i=$((i + 1)); while [ $i -lt $n ]; do paths+=("${args[$i]}"); i=$((i + 1)); done; break ;;
        --max-depth=*|--exact-depth=*|--depth=*) depth="${a#*=}" ;;
        -e|--regexp|-f|--file)
          # rg / grep: the pattern comes from here. fd: `-e` is an extension. ls, tree, ag: plain flags.
          case "$prog" in
            rg|grep|ggrep|egrep|fgrep) pattern=0; i=$((i + 1)) ;;
            fd|fdfind) i=$((i + 1)) ;;
          esac ;;
        --regexp=*|--file=*) pattern=0 ;;
        --search-path) paths+=("$v"); i=$((i + 1)) ;;
        --recursive|--dereference-recursive) recursive=1 ;;
        --*=*) ;;
        -*)
          case " $takes " in *" $a "*)
            case "$prog:$a" in *grep:*) ;; *:-d|*:--max-depth|*:--exact-depth|*:--depth|tree:-L) depth="$v" ;; esac
            i=$((i + 1)) ;;
          esac
          case "$prog:$a" in
            grep*:--*|egrep:--*|fgrep:--*) ;;
            grep*:-*[rR]*|egrep:-*[rR]*|fgrep:-*[rR]*) recursive=1 ;;
            ls:--*|gls:--*) ;;
            ls:-*R*|gls:-*R*) recursive=1 ;;
          esac ;;
        *) if [ $pattern = 1 ]; then pattern=0; else paths+=("$a"); fi ;;
      esac
      i=$((i + 1))
    done
    [ ${#paths[@]} -gt 0 ] || paths=(.)
  fi

  [ $recursive = 1 ] || return 0
  shallow "$depth" && return 0
  for a in "${paths[@]}"; do
    wide "$a" && deny "$prog … $a"
  done
  return 0
}

dir="$cwd" line='' cmdwords=()
flush() {
  local i=0
  # Skip wrappers and VAR=value prefixes to reach the command itself.
  while [ $i -lt ${#cmdwords[@]} ]; do
    case "${cmdwords[$i]}" in sudo|command|time|nice|env|xargs|*=*) i=$((i + 1)) ;; *) break ;; esac
  done
  if [ $i -lt ${#cmdwords[@]} ]; then
    if [ "${cmdwords[$i]}" = cd ]; then
      local to="${cmdwords[$((i + 1))]:-~}"
      case "$to" in /*|'~'*|'$HOME'*|'${HOME}'*) dir="$to" ;; -) ;; *) dir="$dir/$to" ;; esac
    else
      check "${cmdwords[@]:$i}"
    fi
  fi
  cmdwords=()
}
while IFS= read -r line; do
  if [ -z "$line" ]; then flush; else cmdwords+=("$line"); fi
done <<<"$words"
flush
exit 0
