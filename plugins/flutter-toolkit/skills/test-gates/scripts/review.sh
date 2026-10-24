#!/usr/bin/env bash
# plan-mutation-review — post `plan-mutation --diff … --review <file>`'s
# survivors on a PR as one review, one comment per survivor at its line.
#
# Usage: plan-mutation-review <pr> <review.json>
#   A comment already on the PR at the same path and line with the same text is
#   not posted again, so the job can run on every push. A missing or empty file
#   posts nothing. The review is a COMMENT: it neither approves nor blocks.
# Exit: 0 posted, or nothing to post · 1 gh failed · 2 usage.
set -uo pipefail
pr="${1:-}"; file="${2:-}"
[[ $pr =~ ^[0-9]+$ ]] && [ -n "$file" ] || { sed -n '5,9p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
command -v jq >/dev/null || { echo "plan-mutation-review: jq is required" >&2; exit 2; }
[ -s "$file" ] && [ "$(jq length "$file" 2>/dev/null || echo 0)" -gt 0 ] || { echo "plan-mutation-review: no survivors to post"; exit 0; }

repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner) || { echo "plan-mutation-review: gh can't see this repo" >&2; exit 1; }
seen=$(gh api --paginate "repos/$repo/pulls/$pr/comments" --jq '.[] | [.path, (.line // .original_line), .body] | @json') \
  || { echo "plan-mutation-review: can't read PR #$pr's comments" >&2; exit 1; }
# Each listed comment is one JSON array line: [path, line, body].
new=$(printf '%s\n' "$seen" | jq -s . | jq -c --slurpfile seen /dev/stdin \
  '[.[] | select([.path, .line, .body] as $c | ($seen[0] | index([$c]) | not))
        | {path, line, side: "RIGHT", body}]' "$file") \
  || { echo "plan-mutation-review: could not compare $file with PR #$pr's comments" >&2; exit 1; }
n=$(jq length <<< "$new")
[ "$n" -gt 0 ] || { echo "plan-mutation-review: every survivor is already commented on"; exit 0; }
jq -n --argjson comments "$new" --arg body "plan-mutation: $n mutant(s) survived on lines this PR changed. Each one needs a test that pins that behaviour." \
  '{event: "COMMENT", body: $body, comments: $comments}' \
  | gh api -X POST "repos/$repo/pulls/$pr/reviews" --input - >/dev/null \
  || { echo "plan-mutation-review: posting the review on PR #$pr failed" >&2; exit 1; }
echo "plan-mutation-review: posted $n comment(s) on PR #$pr"
