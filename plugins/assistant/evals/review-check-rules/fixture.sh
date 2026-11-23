#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# check.sh prints `<id>=1` when the plugin's text carries a behaviour, `<id>=0` when not.
# Matching is by sentence and keyword, never by a whole sentence, so the wording stays the
# author's. The review check is found by name in the asst-report usage text.
set -euo pipefail
cat > check.sh <<'SH'
root=$1; a="$root/skills/assistant"
K="$a/SKILL.md"; BR="$a/references/brief.md"; BU="$root/agents/builder.md"
V="$root/agents/verifier.md"; FBR="$a/forms/brief-review.md"
# The subcommand the usage text lists besides the five asst-report already had.
sub=$(PATH="$root/bin:$PATH" asst-report 2>&1 | sed -nE 's/.*asst-report[[:space:]]+([a-z][a-z-]*).*/\1/p' \
  | grep -vxE 'put|latest|list|form|summary' | head -1)
CHECK="asst-report ${sub:-NO-SUBCOMMAND}"
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
has b1-before-phases "$BU" -- "$CHECK" 'integration' 'fix'
has b1-fails-blocked "$BU" -- '(fail|non-zero|refus)' '`?blocked`?' 'output'
has b1-fails-no-start "$BU" -- '(fail|non-zero|refus)' '`?blocked`?' "(don.t|do not|never|not) (start|begin|edit|write|touch|change)|without (starting|editing)|stop"
has b2-only-brief "$BU" -- 'only' '(newest|latest|last)[^.]*brief' 'finding'
has b3-dispatch-blocked "$BU" -- 'dispatch' '(design|ruling)' 'brief' '`?blocked`?'
has r1-new-version "$K" "$BR" -- 'approv' '(design|decision|ruling)' 'new (brief )?version|new brief|asst-report put [^ ]+ brief'
has r1-not-elsewhere "$K" "$BR" -- '(design|decision|ruling)' 'chat' '(own|separate|free-form|other|custom|named)[^.]*(file|doc)|(file|doc)[^.]*of (its|their|your) own'
has r2-every-version "$K" "$BR" -- 'brief-review' '(every|each)[^.]*version' '(fresh|new|its own)'
has r2-old-condition "$K" "$BR" "$V" "$FBR" -- 'brief-review' '(class|dependency|persisted format)'
has r2-arch-condition "$K" "$BR" -- 'brief-review' '(when|if|unless|only)[^.]*architecture'
has r3-small-exempt "$K" "$BR" "$BU" -- 'small' 'exempt' "(brief-review|$CHECK|review check|no brief)"
SH
