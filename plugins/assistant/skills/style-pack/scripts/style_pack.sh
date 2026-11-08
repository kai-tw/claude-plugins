#!/usr/bin/env bash
# style-pack — print the style guide's core rules (rules/index.md), the language rules a
# diff needs, and the project rules the project config's `rules:` names, to stdout, so a
# reviewer in any plugin loads one version of the rules.
#
# Usage: style-pack [dart|js …]            core rules + the named language files
#        style-pack --paths <file…>        core rules + the languages those extensions map to
#        style-pack --help
# Extension map (the only copy): .dart → dart · .cs → csharp · .js .mjs .cjs .jsx .ts .tsx → js;
# any other path gets no language file, noted on stderr.
# Project rules: `rules:` in .claude/assistant.md — a file, a directory whose every .md is
# read, or none (a missing line is none). A file with `paths:` frontmatter prints only when
# one of --paths matches one of its globs; a file without it always prints.
# Exit 2 = unknown language name, 1 = the `rules:` path does not exist; nothing printed.
set -uo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd); rules="$here/../rules"
# shellcheck source=../../assistant/scripts/root.sh
source "$here/../../assistant/scripts/root.sh"
case "${1:-}" in --help|-h) sed -n '2,14p' "$0"; exit 0 ;; esac
langs=(); paths=()
if [ "${1:-}" = --paths ]; then
  shift; paths=("$@")
  for p in "$@"; do
    case "$p" in
      *.dart) langs+=(dart) ;;
      *.cs) langs+=(csharp) ;;
      *.js|*.mjs|*.cjs|*.jsx|*.ts|*.tsx) langs+=(js) ;;
      *) echo "style-pack: no language file for '$p' (known: .dart · .cs · .js .mjs .cjs .jsx .ts .tsx) — core and project rules only" >&2 ;;
    esac
  done
else
  for l in "$@"; do
    [ -f "$rules/$l.md" ] && [ "$l" != index ] && [ "$l" != CONVENTIONS ] || { echo "style-pack: unknown language '$l' (known: dart · csharp · js)" >&2; exit 2; }
    langs+=("$l")
  done
fi

root=$(asst_root)
project=$(asst_field "$root/.claude/assistant.md" rules)
case "$project" in
  ""|none) project= ;;
  /*) ;;
  *) project="$root/$project" ;;
esac
[ -z "$project" ] || [ -e "$project" ] || { echo "style-pack: the project config's rules: path '$project' does not exist" >&2; exit 1; }

# A `paths:` glob is relative to the project root, so each --paths entry is made relative to
# the git toplevel it sits in, under either its physical path (git's) or the one cwd
# reached it by through a symlink.
prefix=$(git rev-parse --show-prefix 2>/dev/null)
top=$(git rev-parse --show-toplevel 2>/dev/null) || top=$PWD
ltop=$PWD; [ -z "$prefix" ] || ltop=${PWD%/"${prefix%/}"}
rel=()
for p in ${paths[@]+"${paths[@]}"}; do
  case "$p" in
    "$top"/*) rel+=("${p#"$top"/}") ;;
    "$ltop"/*) rel+=("${p#"$ltop"/}") ;;
    /*) rel+=("$p") ;;
    *) rel+=("$prefix${p#./}") ;;
  esac
done
# A `paths:` glob as an anchored regex: `**/` matches zero or more directories, `*` and `?`
# stay inside one, `{a,b}` is either, `[!a]` is `[^a]`.
glob_re() {
  local g=$1 r= c i depth=0
  for ((i = 0; i < ${#g}; i++)); do
    c=${g:i:1}
    case "$c" in
      '[') if [ "${g:i+1:1}" = '!' ]; then r+='[^'; i=$((i + 1)); else r+='['; fi ;;
      '*') if [ "${g:i+1:1}" = '*' ]; then
             if [ "${g:i+2:1}" = / ]; then r+='(.*/)?'; i=$((i + 2)); else r+='.*'; i=$((i + 1)); fi
           else r+='[^/]*'; fi ;;
      '?') r+='[^/]' ;;
      '{') r+='('; depth=$((depth + 1)) ;;
      '}') r+=')'; depth=$((depth - 1)) ;;
      ',') if [ $depth -gt 0 ]; then r+='|'; else r+=','; fi ;;
      [.+^\$\|\(\)\\]) r+="\\$c" ;;
      *) r+=$c ;;
    esac
  done
  printf '^%s$' "$r"
}
# The globs of a file's leading `paths:` frontmatter, one per line: a scalar, a [a, b] list
# or `- item` lines.
globs_of() {
  awk 'NR == 1 { if ($0 != "---") exit; next }
       $0 == "---" { exit }
       /^paths:/ { on = 1; v = $0; sub(/^paths:[ \t]*/, "", v); if (v != "") { emit(v); on = 0 }; next }
       on && /^[ \t]*-[ \t]*/ { v = $0; sub(/^[ \t]*-[ \t]*/, "", v); emit(v); next }
       { on = 0 }
       function emit(v,  n, a, k, c, d) {
         n = 1; a[1] = v
         if (v ~ /^\[/) {
           gsub(/^\[|\][ \t]*$/, "", v); a[1] = ""
           # A comma inside `{a,b}` belongs to the glob, so only one outside braces splits.
           for (k = 1; k <= length(v); k++) {
             c = substr(v, k, 1)
             if (c == "{") d++; else if (c == "}") d--
             if (c == "," && d <= 0) a[++n] = ""; else a[n] = a[n] c
           }
         }
         for (k = 1; k <= n; k++) { gsub(/^[ \t"\047]+|[ \t"\047]+$/, "", a[k]); if (a[k] != "") print a[k] }
       }' "$1"
}
applies() {
  local g re p any=0 rc
  while IFS= read -r g; do
    any=1; re=$(glob_re "$g")
    for p in ${rel[@]+"${rel[@]}"}; do
      [[ $p =~ $re ]]; rc=$?
      [ $rc = 0 ] && return 0
      # An invalid regex (rc 2) can't say the file doesn't apply, so it prints rather
      # than drop the file unseen.
      [ $rc = 2 ] && { echo "style-pack: invalid paths: glob '$g' in $1 — printed anyway" >&2; return 0; }
    done
  done < <(globs_of "$1")
  [ $any = 0 ]
}

# The file a path really resolves to (readlink -f is not on BSD): follow each link by hand.
real_name() {
  local f=$1 n=0 l
  while [ -L "$f" ] && [ $n -lt 40 ]; do
    l=$(readlink "$f"); n=$((n + 1))
    case "$l" in /*) f=$l ;; *) f="$(dirname -- "$f")/$l" ;; esac
  done
  printf '%s\n' "$f"
}

cat "$rules/index.md"
printf '%s\n' ${langs[@]+"${langs[@]}"} | awk 'NF && !seen[$0]++' | while read -r l; do echo; cat "$rules/$l.md"; done
[ -n "$project" ] || exit 0
if [ -d "$project" ]; then
  find -L "$project" -type f -name '*.md' | LC_ALL=C sort
else
  echo "$project"
fi | while IFS= read -r f; do
  case "$(real_name "$f")" in
    *.md) ;;
    *) echo "style-pack: skipped '$f' — it resolves to a file that is not Markdown" >&2; continue ;;
  esac
  applies "$f" && { echo; cat "$f"; }
done
exit 0
