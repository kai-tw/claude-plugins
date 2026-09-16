#!/usr/bin/env bash
# style-pack — print the 撰寫法母法 (rules/index.md) plus the language files a diff
# needs, to stdout, so a reviewer in any plugin loads one version of the rules.
#
# Usage: style-pack [dart|js …]            母法 + the named language files
#        style-pack --paths <file…>        母法 + the languages those extensions map to
#        style-pack --help
# Extension map (the only copy): .dart → dart · .js .mjs .cjs .jsx .ts .tsx → js.
# Exit 2 = unknown language or extension, nothing printed.
set -uo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); rules="$here/../rules"
case "${1:-}" in --help|-h) sed -n '2,9p' "$0"; exit 0 ;; esac
langs=()
if [ "${1:-}" = --paths ]; then
  shift
  for p in "$@"; do
    case "$p" in
      *.dart) langs+=(dart) ;;
      *.js|*.mjs|*.cjs|*.jsx|*.ts|*.tsx) langs+=(js) ;;
      *) echo "style-pack: no language file for '$p' (known: .dart · .js .mjs .cjs .jsx .ts .tsx)" >&2; exit 2 ;;
    esac
  done
else
  for l in "$@"; do
    [ -f "$rules/$l.md" ] && [ "$l" != index ] && [ "$l" != CONVENTIONS ] || { echo "style-pack: unknown language '$l' (known: dart · js)" >&2; exit 2; }
    langs+=("$l")
  done
fi
cat "$rules/index.md"
printf '%s\n' ${langs[@]+"${langs[@]}"} | awk 'NF && !seen[$0]++' | while read -r l; do echo; cat "$rules/$l.md"; done
