#!/usr/bin/env bash
# ui-text-pack — print the 使用者可見文字撰寫法母法 (rules/index.md) plus the locale
# files a change needs, to stdout, so a reviewer in any plugin loads one version
# of the rules.
#
# Usage: ui-text-pack [zh-Hant|ja|en …]     母法 + the named locale files
#        ui-text-pack --paths <file…>       母法 + the locales those ARB filenames carry
#        ui-text-pack --help
# Locale tags are matched case-insensitively and `_` = `-` (zh_Hant = zh-hant).
# ARB filenames parse as <prefix>_<tag>.arb (app_zh_Hant.arb → zh-Hant).
# A tag with no locale file is NOT an error — the 母法 still binds; the tag is
# named on stderr. Exit 2 = a path that is not an ARB filename, nothing printed.
set -uo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); rules="$here/../rules"
case "${1:-}" in --help|-h) sed -n '2,13p' "$0"; exit 0 ;; esac
tags=()
if [ "${1:-}" = --paths ]; then
  shift
  for p in "$@"; do
    b=$(basename -- "$p")
    case "$b" in
      *_*.arb) tags+=("${b#*_}") ;;
      *) echo "ui-text-pack: '$p' is not an ARB locale file (expected <prefix>_<tag>.arb)" >&2; exit 2 ;;
    esac
  done
  tags=(${tags[@]+"${tags[@]%.arb}"})
else
  tags=("$@")
fi
# Resolve each tag to a rules file, case-insensitively, `_` = `-`. Unmatched tags
# are collected rather than fatal: no locale file means the 母法 alone binds.
files=(); missing=()
for t in ${tags[@]+"${tags[@]}"}; do
  norm=$(printf '%s' "$t" | tr 'A-Z_' 'a-z-')
  hit=
  for f in "$rules"/*.md; do
    n=$(basename -- "$f" .md)
    [ "$n" = index ] || [ "$n" = CONVENTIONS ] && continue
    [ "$(printf '%s' "$n" | tr 'A-Z_' 'a-z-')" = "$norm" ] && { hit=$f; break; }
  done
  if [ -n "$hit" ]; then files+=("$hit"); else missing+=("$t"); fi
done
cat "$rules/index.md"
printf '%s\n' ${files[@]+"${files[@]}"} | awk 'NF && !seen[$0]++' | while read -r f; do echo; cat "$f"; done
[ ${#missing[@]} -eq 0 ] || echo "ui-text-pack: no locale file for: ${missing[*]} (母法 only)" >&2
