#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# stub/ntn stands in for the Notion CLI: one KB root holding a TaskList whose
# unfiltered query spans three pages of two rows (five rows in all), the way a
# real `ntn datasources query` hands back 25 at a time with a next_cursor. A
# status filter answers with the matching row alone. Every query is logged.
set -euo pipefail
git init -q
mkdir -p .claude stub
printf 'board: notion\nnotion_root: 11111111111111111111111111111111\n' > .claude/assistant.md
cat > stub/ntn <<'SH'
#!/usr/bin/env bash
row() { printf '{"id":"p%s","url":"u%s","properties":{"Name":{"type":"title","title":[{"plain_text":"Task %s"}]},"Status":{"type":"status","status":{"name":"%s"}},"Stage":{"type":"status","status":{"name":"Review"}},"Trigger":{"type":"rich_text","rich_text":[]}}}' "$1" "$1" "$1" "$2"; }
case "$1 $2" in
  "api v1/blocks/"*) echo '{"results":[{"type":"child_database","id":"db1","child_database":{"title":"TaskList"}}]}' ;;
  "datasources resolve") echo '{"data_sources":[{"id":"ds1"}]}' ;;
  "api v1/data_sources/"*) echo '{"properties":{}}' ;;
  "datasources query")
    echo "query $*" >> "$EVAL_WS/ntn.log"
    args="$*"
    case "$args" in
      *'"In Progress"'*) echo "{\"results\":[$(row 1 'In Progress')],\"has_more\":false,\"next_cursor\":null}" ;;
      *'"Next"'*)        echo "{\"results\":[$(row 2 Next)],\"has_more\":false,\"next_cursor\":null}" ;;
      *--start-cursor\ c3*) echo "{\"results\":[$(row 5 Shipped)],\"has_more\":false,\"next_cursor\":null}" ;;
      *--start-cursor\ c2*) echo "{\"results\":[$(row 3 Backlog),$(row 4 Backlog)],\"has_more\":true,\"next_cursor\":\"c3\"}" ;;
      *) echo "{\"results\":[$(row 1 'In Progress'),$(row 2 Next)],\"has_more\":true,\"next_cursor\":\"c2\"}" ;;
    esac ;;
  *) echo "{}" ;;
esac
SH
chmod +x stub/ntn
