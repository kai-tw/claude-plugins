#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh prints each `## S<N>` heading and each rule bullet of index.md, dart.md and js.md
# on one line, prefixed by its file, so a grader can pin a rule's wording to the rule it is
# filed under without pinning the sub-check number; then it counts the files tracked under
# skills/, agents/ and hooks/ and prints every line among them that says guard.
# hooks/stale-check.sh is skipped by name, and only that file: it is shared byte-for-byte by
# five plugins, so its wording must change in all five at once and is tracked outside this case.
set -euo pipefail
cat > check.sh <<'SH'
root=$1; r="$root/skills/style-pack/rules"
for f in index dart js; do
  awk '/^## S[0-9]/ { if (b != "") print b; b = ""; print; next }
       /^- \*\*S[0-9]/ { if (b != "") print b; b = $0; next }
       /^(## |$|\*\*|- )/ { if (b != "") print b; b = ""; next }
       b != "" { b = b " " $0 }
       END { if (b != "") print b }' "$r/$f.md" | tr -s ' ' | sed "s|^|$f.md: |"
done
cd "$root" || exit 1
files=$(git ls-files skills agents hooks 2>/dev/null) || files=$(find skills agents hooks -type f)
echo "scanned=$(grep -c . <<<"$files")"
while IFS= read -r p; do
  [ "$p" = hooks/stale-check.sh ] && continue
  grep -nIiE '\bguard(s|ed|ing)?\b' "$p" | sed "s|^|guard=$p:|"
done <<<"$files"
true
SH
