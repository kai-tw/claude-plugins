#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# A stub `gh` in ./stub answers with fixed JSON, so the filters run without a network.
set -euo pipefail
git init -q
mkdir -p stub
cat > stub/gh <<'SH'
#!/usr/bin/env bash
case "$1 $2" in
  "auth status"|"repo view") exit 0 ;;
  "issue list") echo '[{"number":12,"title":"Crash on import"}]' ;;
  "pr list")
    case "$*" in
      *review-requested*) echo '[{"number":40,"title":"Teammate change"}]' ;;
      *) echo '[
        {"number":41,"title":"Green PR","reviewDecision":"APPROVED","statusCheckRollup":[{"conclusion":"SUCCESS"}]},
        {"number":42,"title":"Needs edits","reviewDecision":"CHANGES_REQUESTED","statusCheckRollup":[]},
        {"number":43,"title":"Red CI","reviewDecision":"","statusCheckRollup":[{"conclusion":"SUCCESS"},{"state":"FAILURE"}]}
      ]' ;;
    esac ;;
  *) exit 1 ;;
esac
SH
chmod +x stub/gh
