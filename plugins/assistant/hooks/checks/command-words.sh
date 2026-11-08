#!/usr/bin/env bash
# command-words.sh — sourced by the PreToolUse(Bash) hooks that act on what a
# command runs: splits a command line into simple commands and their words the
# way the shell does, for bash 3.2 (macOS's /bin/bash).
#
# Not expanded: $VAR, $(…), `…`, globs. A word holding one is kept as written,
# and word_unknown tells the caller it cannot be read.

# command_words <cmd> — each simple command of <cmd>, every word ended by \037
# and every command by \036. Commands end at a newline, ; & && | || ( or )
# outside quotes; quotes are removed, backslash escapes applied, redirections,
# comments and here-document bodies dropped. The commands inside a $(…) or `…`
# come too, before the command holding it, as the shell runs them. A subshell —
# a $(…), `…` or ( … ) — opens with the record \034( and closes with \034).
command_words() {
  local rec
  while IFS= read -r -d $'\036' rec; do
    case "$rec" in
      $'\035'*) printf '\034(\036'; command_words "${rec#?}"; printf '\034)\036' ;;
      *) printf '%s\036' "$rec" ;;
    esac
  done < <(command_words_awk "$1")
}

# command_words_awk <cmd> — command_words for <cmd> without reading inside a
# substitution: each one's text comes as a record of its own, marked by a
# leading \035, before the command holding it.
command_words_awk() {
  # awk, not sed: BSD sed writes a literal `n` for `\n`. LC_ALL=C walks bytes,
  # which keeps every multibyte character whole between the ASCII ones it looks for.
  printf '%s' "$1" | LC_ALL=C awk '
    function word() {
      if (inw && !skip) cur = cur w "\037"
      else if (inw && heredoc == "?") heredoc = w
      if (inw) skip = 0
      w = ""; inw = 0
    }
    function end() { word(); skip = 0; printf "%s%s\036", subs, cur; subs = cur = "" }
    # The next character, or one no test matches past the end: BSD awk finds ""
    # in every string, so a lookahead returning "" would loop forever.
    function nx() { return i < n ? substr(s, i + 1, 1) : "\001" }
    { s = s (NR > 1 ? "\n" : "") $0 }
    END {
      n = length(s)
      for (i = 1; i <= n; i++) {
        c = substr(s, i, 1)
        if (q == "\047") { if (c == "\047") q = ""; else w = w c; continue }
        # $(…) stays whole, quotes and all, up to its matching parenthesis: a
        # quote in a here-document inside it would otherwise end the word.
        if (c == "$" && nx() == "(") {
          w = w "$("; i += 2; d = 1; st = i
          while (i <= n && d > 0) { c = substr(s, i, 1); if (c == "(") d++; else if (c == ")") d--; w = w c; i++ }
          i--; inw = 1; subs = subs "\035" substr(s, st, i - st + (d > 0)) "\036"; continue
        }
        # `…` likewise, up to the next unescaped backquote; \` \\ \$ in it are unescaped.
        if (c == "`") {
          t = ""
          for (i++; i <= n && substr(s, i, 1) != "`"; i++) {
            c = substr(s, i, 1)
            if (c == "\\" && index("`\\$", nx())) { i++; c = substr(s, i, 1) }
            t = t c
          }
          w = w "`" t "`"; inw = 1; subs = subs "\035" t "\036"; continue
        }
        if (q == "\"") {
          if (c == "\\" && index("\"\\$`", nx())) { i++; w = w substr(s, i, 1) }
          else if (c == "\"") q = ""
          else w = w c
          continue
        }
        if (c == "\\") { i++; if (i <= n && substr(s, i, 1) != "\n") { w = w substr(s, i, 1); inw = 1 }; continue }
        if (c == "\047" || c == "\"") { q = c; inw = 1; continue }
        if (c == "#" && !inw) { while (i < n && nx() != "\n") i++; continue }
        if (c == " " || c == "\t") { word(); continue }
        # A redirection: drop a leading fd number, the operator and its target.
        if (c == ">" || c == "<" || (c == "&" && nx() == ">")) {
          if (w ~ /^[0-9]+$/) { w = ""; inw = 0 } else word()
          op = c; while (index("<>&|-", nx())) { i++; op = op substr(s, i, 1) }
          if (op ~ /&-?$/) { while (nx() ~ /[0-9]/) i++; continue }
          if (op ~ /^<<-?$/) { heredoc = "?"; strip = (op == "<<-") }
          skip = 1; continue
        }
        if (c == "\n") {
          end()
          # A here-document body is input, not commands: skip it and its delimiter line.
          while (heredoc != "" && heredoc != "?" && i < n) {
            j = index(substr(s, i + 1), "\n"); line = j ? substr(s, i + 1, j - 1) : substr(s, i + 1)
            i += j ? j : length(line)
            if (strip) sub(/^\t+/, "", line)
            if (line == heredoc || !j) break
          }
          heredoc = ""; continue
        }
        if (index(";&|", c)) { end(); continue }
        if (c == "(" || c == ")") { end(); printf "\034%s\036", c; continue }
        w = w c; inw = 1
      }
      end()
    }'
}

# read_command — reads the next command of command_words' output from stdin into
# the array CMD_WORDS, minus what runs it without being it: VAR=x assignments,
# `command`, `sudo`, `env`, `exec`, `nohup`, `time` and the keywords `if then
# else elif do while until ! {`. CMD_DIR, set by the caller to where the whole
# command runs, is kept as the directory each command runs in (empty when it
# cannot be read here): a cd or pushd moves it and is not returned, and the end
# of a subshell restores it, as the shell does. Fails at the end of the input.
CMD_DIR='' CMD_DIRS=()
read_command() {
  local rec w d n
  while IFS= read -r -d $'\036' rec; do
    n=${#CMD_DIRS[@]}
    case "$rec" in
      $'\034(') CMD_DIRS+=("$CMD_DIR"); continue ;;
      # A ) with no ( open ends a case pattern, not a subshell.
      $'\034)') [ "$n" -gt 0 ] || continue; CMD_DIR=${CMD_DIRS[$((n - 1))]}; unset "CMD_DIRS[$((n - 1))]"; continue ;;
    esac
    CMD_WORDS=()
    while IFS= read -r -d $'\037' w; do
      if [ ${#CMD_WORDS[@]} -eq 0 ]; then
        case "$w" in
          command|sudo|env|exec|nohup|time|if|then|else|elif|do|while|until|'!'|'{') continue ;;
          [A-Za-z_]*=*) [[ ${w%%=*} =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] && continue ;;
        esac
      fi
      CMD_WORDS+=("$w")
    done <<<"$rec"
    if d=$(cd_dir "$CMD_DIR"); then CMD_DIR=$d; continue; fi
    return 0
  done
  return 1
}

# word_unknown <word> — succeeds when <word> holds an expansion this file does not
# perform, so its value cannot be read here.
word_unknown() { case "$1" in *'$'*|*'`'*|'~'*|*'*'*|*'?'*) return 0 ;; esac; return 1; }

# word_dir <dir> <word> — the directory <word> names, relative to <dir>; nothing
# when it cannot be read here (an expansion, `cd -`, an unknown <dir>).
word_dir() {
  local d=$1 p=$2
  case "$p" in '~') p=${HOME:-} ;; '~/'*) p=${HOME:-}/${p#'~/'} ;; esac
  [ -n "$p" ] && [ "$p" != - ] && ! word_unknown "$p" || return 0
  case "$p" in /*) echo "$p" ;; *) [ -z "$d" ] || echo "$d/$p" ;; esac
}

# cd_dir <dir> — when CMD_WORDS is a cd or pushd, the directory it moves to from
# <dir> (empty when that cannot be read here); fails for any other command.
cd_dir() {
  case "${CMD_WORDS[0]:-}" in cd|pushd) ;; *) return 1 ;; esac
  local last=${CMD_WORDS[${#CMD_WORDS[@]}-1]}
  [ ${#CMD_WORDS[@]} -gt 1 ] || last='~'
  word_dir "$1" "$last"
}

# git_command <dir> — when CMD_WORDS is a git command, sets GIT_SUB to its
# subcommand, GIT_ARGS to the words after it and GIT_AT to the directory it
# runs in after every -C (empty when that cannot be read here); fails otherwise.
git_command() {
  [ "${CMD_WORDS[0]:-}" = git ] || return 1
  local i=1 n=${#CMD_WORDS[@]} w
  GIT_AT=$1 GIT_SUB='' GIT_ARGS=()
  while [ $i -lt $n ]; do
    w=${CMD_WORDS[$i]}; i=$((i + 1))
    case "$w" in
      -C) GIT_AT=$(word_dir "$GIT_AT" "${CMD_WORDS[$i]:-}"); i=$((i + 1)) ;;
      -c|--git-dir|--work-tree|--namespace|--config-env|--super-prefix) i=$((i + 1)) ;;
      -*) ;;
      *) GIT_SUB=$w; break ;;
    esac
  done
  [ $i -lt $n ] && GIT_ARGS=("${CMD_WORDS[@]:$i}")
  return 0
}
