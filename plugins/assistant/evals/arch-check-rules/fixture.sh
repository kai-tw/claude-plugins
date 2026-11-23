#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh prints `<id>=1` when the plugin's text carries a behaviour, `<id>=0` when not.
# Sentences are matched by keyword, as in review-check-rules; the two conditions and the
# Ownership criterion are matched as whole phrases, since they must read the same everywhere.
set -euo pipefail
cat > check.sh <<'SH'
root=$1; a="$root/skills/assistant"
K="$a/SKILL.md"; V="$a/references/verify.md"; BR="$a/references/brief.md"; R="$a/scripts/report.sh"
F="$a/forms/advise.md"; AD="$root/agents/advisor.md"; BU="$root/agents/builder.md"
# One sentence per line: split at blank lines, list items and `. `.
sent() {
  perl -0777 -ne 's/\r//g; for (split /\n\s*\n|\n(?=\s*(?:- |\d+\. |#))|(?<=\.)\s+(?=[A-Z`*])/) { s/\s+/ /g; print "$_\n" if /\S/ }' "$@"
}
# has <id> <files…> -- <regex…>: 1 when one sentence matches every regex (case-insensitive).
has() {
  local id=$1; shift; local files=() res=()
  while [ "$1" != -- ]; do files+=("$1"); shift; done; shift
  local s; s=$(sent "${files[@]}")
  for r in "$@"; do s=$(grep -iE -- "$r" <<<"$s"); done
  [ -n "$s" ] && echo "$id=1" || echo "$id=0"
}
# flat <file>: one line, backticks and backslashes dropped, runs of blanks as one space.
flat() { tr -d '`\\' < "$1" | tr -s ' \n\t' '   '; }
# The form: the line after `## Architecture check`, and lines starting `Root cause:` elsewhere.
first=$(awk '/^## Architecture check[[:space:]]*$/ {on=1; next} on && NF {print; exit}' "$F")
grep -qE '^Root cause: ' <<<"$first" && grep -q 'not architecture' <<<"$first" && echo "form-arch-section=1" || echo "form-arch-section=0"
echo "form-finding-root-cause=$(awk '/^## Architecture check[[:space:]]*$/ {on=1; next} /^## / {on=0} !on && /^Root cause:/' "$F" | grep -c . || true)"
# The Ownership criterion as brief.md §Choosing the design states it, quoted word for word.
own=$(flat "$BR" | grep -oE '2\. Ownership\. [^0-9]*No other layer[^.]*\.' | sed 's/^2\. Ownership\. //')
[ -n "$own" ] && flat "$F" | grep -qF -- "$own" && echo "form-ownership-verbatim=1" || echo "form-ownership-verbatim=0"
# advisor.md: the architecture-check dispatch, in the description and the body.
desc=$(awk 'NR==1 && /^---$/ {f=1; next} f && /^---$/ {exit} f' "$AD")
grep -qi 'architecture check' <<<"$desc" && echo "advisor-desc-arch=1" || echo "advisor-desc-arch=0"
has advisor-trigger "$AD" -- 'architecture check' 'trigger'
has advisor-no-fix "$AD" -- 'architecture' "(needs? no|without( a| any)?|no|doesn.t need|does not need|not need)[^.]*fix.? finding"
has advisor-section-rule "$AD" -- 'section' 'finding' 'architecture check'
# builder.md: advice whose advise report says `Root cause: architecture` is not implemented.
has builder-arch-no-implement "$BU" -- 'Root cause: architecture' "(don.t|do not|never|not|isn.t|is not)[^.]*(implement|build|apply)|blocked"
# The two conditions in one wording in report.sh's message, SKILL.md and verify.md.
ca='(2nd|second) brief version filed after the first build-\* report'
cb='first verify-code report after the (2nd|second) build-fix round has an? \[1\.<?n>?\] fix finding in its Logic block'
for c in a:"$ca" b:"$cb"; do
  id=${c%%:*}; re=${c#*:}; seen=""
  for f in R:"$R" K:"$K" V:"$V"; do
    p=$(flat "${f#*:}" | grep -oE -- "$re" | head -1)
    [ -n "$p" ] && echo "cond-$id-${f%%:*}=1" || echo "cond-$id-${f%%:*}=0"
    seen+="$p"$'\n'
  done
  [ "$(grep -c . <<<"$seen")" = 3 ] && [ "$(sort -u <<<"$seen" | grep -c .)" = 1 ] && echo "cond-$id-same=1" || echo "cond-$id-same=0"
done
# verify.md: the architecture-check dispatch is outside "never a second for the same finding".
has verify-arch-exempt "$V" -- 'architecture' '(never a second|same finding)'
SH
