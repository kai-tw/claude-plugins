#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# review.json has two survivors; PR 7 already carries a comment identical to
# the first. empty.json is an empty list. fake/gh answers the comment listing
# the way `gh api --jq` would, one JSON line per comment, and saves the review
# it is asked to post.
set -euo pipefail
mkdir -p fake
cat > fake/gh <<'GH'
#!/usr/bin/env bash
case "$*" in
  "repo view"*) echo "o/r" ;;
  *"pulls/7/comments"*) printf '%s\n' '["lib/a.dart",2,"Mutant survived: x"]' ;;
  *"-X POST repos/o/r/pulls/7/reviews"*) cat > "$EVAL_WS/posted.json"; echo '{}' ;;
  *) exit 1 ;;
esac
GH
chmod +x fake/gh
printf '[{"path":"lib/a.dart","line":2,"body":"Mutant survived: x"},{"path":"lib/a.dart","line":5,"body":"Mutant survived: y"}]' > review.json
printf '[]' > empty.json
