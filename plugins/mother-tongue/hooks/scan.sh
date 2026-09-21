#!/usr/bin/env bash
# scan.sh <locale> — read prose on stdin, print its banned terms as one line
# "wrong→right、…", or nothing. A locale without banned.tsv never matches.
#
# Code and `backtick spans` are stripped first: that is how a reply quotes a
# banned term on purpose (explaining the rule itself) without being blocked.
set -uo pipefail
list="$(cd "$(dirname "$0")/.." && pwd)/locales/${1:-}/banned.tsv"
[ -n "${1:-}" ] && [ -r "$list" ] || exit 0
text=$(perl -0777 -pe 's/```.*?```//gs; s/`[^`\n]*`//g')
while IFS=$'\t' read -r wrong right; do
  [ -n "$wrong" ] && grep -qF -- "$wrong" <<<"$text" && printf '%s→%s\n' "$wrong" "$right"
done < "$list" | awk 'NR>1{printf "、"}{printf "%s", $0}'
