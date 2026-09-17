#!/usr/bin/env bash
# asst-intake — to-do candidates outside the board: GitHub issues / PRs and open
# session-journal threads. A source that cannot be read prints a `skip` line with
# the reason, so "unavailable" never looks like "nothing to do".
#
# Usage: asst-intake [project-dir]      (default: cwd)
# Output, one line per item, tab-separated:  <ref>	<title>	<why>
#   issue#<n>        open issue assigned to me
#   pr#<n>           open PR: review requested from me · mine with changes requested · mine with failing checks
#   journal:<title>  open thread in docs/session-journal/_active.md (why = its Next line)
#   skip <source>: <reason>
set -uo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/root.sh"
dir="${1:-$PWD}"
cd "$dir" 2>/dev/null || { echo "asst-intake: no such directory: $dir" >&2; exit 2; }

github() {
  command -v gh >/dev/null || { echo "skip github: gh not installed"; return; }
  command -v jq >/dev/null || { echo "skip github: jq not installed"; return; }
  gh auth status >/dev/null 2>&1 || { echo "skip github: gh not authenticated"; return; }
  gh repo view --json name >/dev/null 2>&1 || { echo "skip github: no GitHub remote"; return; }
  local out
  out=$(gh issue list --assignee @me --state open --json number,title) || { echo "skip github: issue list failed"; return; }
  jq -r '.[] | "issue#\(.number)\t\(.title)\tassigned"' <<<"$out"
  out=$(gh pr list --state open --search 'review-requested:@me' --json number,title) || { echo "skip github: pr list failed"; return; }
  jq -r '.[] | "pr#\(.number)\t\(.title)\treview requested"' <<<"$out"
  out=$(gh pr list --state open --author @me --json number,title,reviewDecision,statusCheckRollup) || { echo "skip github: pr list failed"; return; }
  jq -r '.[]
    | ([.statusCheckRollup[]? | (.conclusion // .state)] | any(. == "FAILURE" or . == "ERROR" or . == "TIMED_OUT")) as $red
    | select(.reviewDecision == "CHANGES_REQUESTED" or $red)
    | "pr#\(.number)\t\(.title)\t\(if .reviewDecision == "CHANGES_REQUESTED" then "changes requested" else "checks failing" end)"' <<<"$out"
}

journal() {
  local f
  f="$(asst_root)/docs/session-journal/_active.md"
  [ -f "$f" ] || { echo "skip journal: no docs/session-journal/_active.md"; return; }
  # Drop <!-- … --> (the template lives in one), then one line per `## <title> · <status>` block.
  awk '
    /<!--/ { c = 1 }
    c { if (/-->/) c = 0; next }
    function flush() { if (t != "") { r = t; sub(/ *·.*/, "", r); printf "journal:%s\t%s\t%s\n", r, t, n } }
    /^## / { flush(); t = substr($0, 4); n = "" ; next }
    /^- \*\*Next:\*\*/ { n = $0; sub(/^- \*\*Next:\*\* */, "", n) }
    END { flush() }
  ' "$f"
}

github
journal
