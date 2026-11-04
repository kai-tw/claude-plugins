#!/usr/bin/env bash
# write-check.sh — PreToolUse(Write|Edit|MultiEdit): block a file write whose
# comments or prose add a banned term, the same list stop.sh checks replies with.
#
# Only what a person reads is checked: the whole text of Markdown and plain-text
# files, and only the comments of code files. Code itself is left alone, so a
# variable that happens to be named `gate` is never blocked. Other file types
# aren't checked.
#
# A term already in the text being replaced (Edit's old_string, or the file on
# disk for Write) doesn't count: editing a line near an old term must not block.
#
# Lines with Han characters are checked against $MOTHER_TONGUE_ZH's list, Latin
# lines against `en`'s, so a Chinese comment and an English one in the same file
# are each held to their own language.
set -uo pipefail
[ "${MOTHER_TONGUE:-on}" = off ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0
here=$(cd "$(dirname "$0")" && pwd)
input=$(cat)
tool=$(jq -r '.tool_name // empty' <<<"$input")
path=$(jq -r '.tool_input.file_path // empty' <<<"$input")
[ -n "$path" ] || exit 0

case "$tool" in
  Write) new=$(jq -r '.tool_input.content // empty' <<<"$input")
         old=$(cat "$path" 2>/dev/null) ;;
  Edit)  new=$(jq -r '.tool_input.new_string // empty' <<<"$input")
         old=$(jq -r '.tool_input.old_string // empty' <<<"$input") ;;
  MultiEdit) new=$(jq -r '[.tool_input.edits[]?.new_string] | join("\n")' <<<"$input")
         old=$(jq -r '[.tool_input.edits[]?.old_string] | join("\n")' <<<"$input") ;;
  *) exit 0 ;;
esac
[ -n "$new" ] || exit 0

name=${path##*/}; ext=${name##*.}; [ "$ext" = "$name" ] && ext=""
case "$(tr '[:upper:]' '[:lower:]' <<<"$ext")" in
  md|markdown|mdx|txt|rst) style=prose ;;
  dart|js|jsx|ts|tsx|mjs|cjs|java|kt|kts|swift|c|h|cc|cpp|hpp|m|mm|cs|go|rs|scala|groovy|gradle|php|css|scss|less) style=slash ;;
  sh|bash|zsh|py|rb|pl|pm|r|yaml|yml|toml|ps1|conf) style=hash ;;
  *) case "$name" in Makefile|Dockerfile|.*rc) style=hash ;; *) exit 0 ;; esac ;;
esac

# The prose a person reads: all of it, or the comments only.
prose() {
  STYLE=$style perl -CSD -0777 -ne '
    my $s = $ENV{STYLE};
    if ($s eq "prose") { print; exit }
    my @o;
    if ($s eq "slash") {
      while (m{/\*(.*?)(?:\*/|\z)}gs) { (my $b = $1) =~ s/^[ \t]*\*+[ \t]?//mg; push @o, $b }
      s{/\*.*?(?:\*/|\z)}{}gs;
      for (split /\n/) { push @o, $1 if m{(?:^|\s)//+!?[ \t]?(.*)}; push @o, $1 if m{^\s*\*+(?!/)[ \t]?(.*)} }
    } else {
      for (split /\n/) { next if /^#!/; push @o, $1 if /(?:^|\s)#+[ \t]?(.*)/ }
    }
    print join "\n", @o;
  '
}
# Lines with Han characters, or Latin-only lines.
han()   { perl -CSD -ne 'print if /\p{Han}/'; }
latin() { perl -CSD -ne 'print unless /[\p{Han}\p{Hiragana}\p{Katakana}\p{Hangul}]/'; }
# scan.sh hits in $2 that aren't already in $3, for locale $1.
added() {
  local a b; a=$("$here/scan.sh" "$1" <<<"$2"); [ -n "$a" ] || return 0
  b=$("$here/scan.sh" "$1" <<<"$3")
  A=$a B=$b perl -CSD -Mutf8 -e '
    my ($new, $old) = map { my $x = $_ // ""; utf8::decode($x); $x } @ENV{qw(A B)};
    my %seen = map { $_ => 1 } split /、/, $old;
    print join "、", grep { !$seen{$_} } split /、/, $new;
  '
}

np=$(prose <<<"$new"); op=$(prose <<<"$old")
zh="${MOTHER_TONGUE_ZH:-zh-TW}"
hits=$(added "$zh" "$(han <<<"$np")" "$(han <<<"$op")")
en=$(added en "$(latin <<<"$np")" "$(latin <<<"$op")")
[ -n "$en" ] && hits="${hits:+$hits、}$en"
[ -n "$hits" ] || exit 0

where=comments; [ "$style" = prose ] && where=text
jq -n --arg h "$hits" --arg f "$name" --arg w "$where" '{hookSpecificOutput:{hookEventName:"PreToolUse",
  permissionDecision:"deny",
  permissionDecisionReason:("The " + $w + " you are writing to " + $f + " use terms that are not standard usage: " + $h
    + ". Rewrite them and write the file again. If you are quoting a term itself, put it in backticks.")}}'
