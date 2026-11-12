#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh prints `<id>=1` when the plugin's text carries a behaviour of the architecture
# document, `<id>=0` when not. Matching is by sentence and keyword, never by a whole
# sentence, so the wording stays the author's.
set -euo pipefail
cat > check.sh <<'SH'
root=$1; a="$root/skills/assistant"
P="$a/references/project.md"; K="$a/SKILL.md"; BR="$a/references/brief.md"
V="$root/agents/verifier.md"; BU="$root/agents/builder.md"; FBR="$a/forms/brief-review.md"; FI="$a/forms/investigation.md"
# One sentence per line: split at blank lines, list items, config lines and `. `.
sent() {
  perl -0777 -ne 's/\r//g; for (split /\n\s*\n|\n(?=\s*(?:- |\d+\. |#|[a-z_]+:\s))|(?<=\.)\s+(?=[A-Z`*])/) { s/\s+/ /g; print "$_\n" if /\S/ }' "$@"
}
# has <id> <files…> -- <regex…>: 1 when one sentence matches every regex (case-insensitive).
has() {
  local id=$1; shift; local files=() res=()
  while [ "$1" != -- ]; do files+=("$1"); shift; done; shift
  local s; s=$(sent "${files[@]}")
  for r in "$@"; do s=$(grep -iE -- "$r" <<<"$s"); done
  [ -n "$s" ] && echo "$id=1" || echo "$id=0"
}
ARCH='architecture'
# Block 5 of the code review, heading excluded.
block5=$(awk '/^5\. \*\*Built vs approved design\*\*/ { on = 1; sub(/.*\*\*Built vs approved design\*\*/, "") } /^6\. \*\*/ { on = 0 } on' "$V" | tr -s ' \n' ' ')
# The verifier's brief: the paragraph that starts with `Brief:`.
vbrief=$(awk '/^Brief:/ { on = 1 } on && /^$/ { exit } on' "$V" | tr -s ' \n' ' ')

grep -qE '^architecture:[[:space:]].*none' "$P" && echo b1-field=1 || echo b1-field=0
has b1-missing-none "$P" -- "$ARCH" 'missing|absent|omitted|unset|no entry|left out|without' 'none'
has b2-directory "$P" "$K" "$BR" "$V" "$BU" "$FI" -- "$ARCH" 'director|folder' '\.md'
has s1-brief-step "$BR" -- "$ARCH" 'brief-review'
has s1-investigation "$FI" -- "$ARCH"
grep -E '^- Ownership:' "$BR" | grep -qiE "$ARCH|heading" && echo s1-ownership-cites=1 || echo s1-ownership-cites=0
has s1-path-and-heading "$BR" -- 'path' 'heading'
has s1-no-copy "$BR" -- 'heading' '(never|not|no|without)[^.]*(cop|quot|restat|reproduc|paste)'
grep -qi "$ARCH" "$BR" && has s2-needs-you "$BR" -- 'depart|deviat|violat|contradict|conflict|break|against|differ' 'Needs you' || echo s2-needs-you=0
has s3-brief-review-files "$FBR" "$V" -- "$ARCH|depart|deviat|violat|contradict|conflict" 'Needs you'
grep -qi "$ARCH" <<<"$block5" && echo s4-block5=1 || echo s4-block5=0
grep -qi "$ARCH" <<<"$vbrief" && echo s4-verifier-input=1 || echo s4-verifier-input=0
grep -qi "$ARCH" <<<"$block5" && grep -qiE 'approv|picked|ruled|chose|Needs you' <<<"$block5" && echo s5-approved-exempt=1 || echo s5-approved-exempt=0
has s5-doc-in-diff "$P" "$K" "$BR" "$V" "$BU" -- "$ARCH" 'diff|\bPR\b|pull request|edits|updates|rewrites'
s6a=$(has x "$K" -- 'brief-review' "$ARCH"); s6b=$(has x "$K" "$V" "$FBR" -- "$ARCH" 'every|each|always' 'brief')
[ "$s6a" = x=1 ] || [ "$s6b" = x=1 ] && echo s6-every-brief=1 || echo s6-every-brief=0
SH
