#!/usr/bin/env bash
# md_section.sh — edit ONE `## ` section of a local plan body (the bodyFile), so a
# rev emits the changed section instead of the whole plan. Upload afterwards with
# `notion-payload update <manifest> --commit` (bodyFile) or `plan-store put`.
#
# Usage: plan-section replace <file> <heading> [md|-]   body under `## <heading>` := input (heading kept)
#        plan-section append  <file> <heading> [md|-]   input added at the section's end
#        plan-section get     <file> <heading>          print heading + body
# <heading> is the literal text after `## ` in the file. Exit 1 = heading absent (the
# headings present are listed), 2 = bad usage. Written via a sibling + mv, so a failed
# write never leaves a half-edited plan.
set -uo pipefail
op="${1:-}"; file="${2:-}"; heading="${3:-}"; src="${4:--}"
case "$op" in replace|append|get) ;; *) sed -n '5,7p' "$0" >&2; exit 2 ;; esac
[ -n "$file" ] && [ -n "$heading" ] || { sed -n '5,7p' "$0" >&2; exit 2; }
[ -f "$file" ] || { echo "plan-section: no such file: $file" >&2; exit 2; }
if ! grep -qxF -- "## $heading" "$file"; then
  echo "plan-section: no section \"## $heading\" in $file. Headings present:" >&2
  grep -E '^## ' "$file" | sed 's/^/  /' >&2; exit 1
fi
if [ "$op" = get ]; then
  awk -v h="## $heading" '$0==h{p=1;print;next} p&&/^## /{exit} p' "$file"; exit 0
fi
in=$(mktemp); if [ "$src" = "-" ]; then cat > "$in"; else cat "$src" > "$in" || { rm -f "$in"; exit 2; }; fi
tmp="$file.partial"
# input goes through a file, not `-v`: awk -v interprets backslashes in the value.
awk -v h="## $heading" -v op="$op" -v inf="$in" '
  function flush() { if (op=="append") { while (n>0 && buf[n]=="") n--; for (i=1;i<=n;i++) print buf[i] }
                     while ((getline l < inf) > 0) print l; close(inf); print ""; }
  $0==h && !done { print; insec=1; n=0; next }
  insec && /^## / { flush(); insec=0; done=1 }
  insec { if (op=="append") buf[++n]=$0; next }
  { print }
  END { if (insec) flush() }
' "$file" > "$tmp" && mv -f "$tmp" "$file" || { rm -f "$tmp" "$in"; exit 2; }
rm -f "$in"
echo "plan-section: $op \"## $heading\" in $file"
