#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# stub/ntn stands in for the Notion CLI: one KB root holding KB Pages with two
# rows. Any call that would write (a POST, a PATCH, `pages edit`) is logged as
# "write …" in ntn.log; the stub answers a page create as if it had worked,
# marker included, so a create that is let through exits 0.
set -euo pipefail
git init -q
mkdir -p stub
: > ntn.log
printf '{"db":"kb-pages","rows":[{"Name":"Billing rules"}]}' > manifest.json
cat > stub/ntn <<'SH'
#!/usr/bin/env bash
row() { printf '{"id":"p%s","url":"u%s","properties":{"Name":{"type":"title","title":[{"plain_text":"%s"}]},"Module":{"type":"select","select":null},"Kind":{"type":"select","select":null}}}' "$1" "$1" "$2"; }
case "$*" in
  *"-X POST"*|*"-X PATCH"*|"pages edit"*|"pages trash"*) echo "write $*" >> "$EVAL_WS/ntn.log" ;;
esac
case "$1 $2" in
  "api v1/pages/task1") echo '{"parent":{"type":"data_source_id","data_source_id":"ds-tasks"}}' ;;
  "api v1/pages/idless1") echo '{"parent":{"type":"data_source_id"}}' ;;
  "api v1/pages/idless2") echo '{"parent":{"type":"database_id"}}' ;;
  "api v1/data_sources/ds-tasks") echo '{"title":[{"plain_text":"TaskList"}],"properties":{}}' ;;
  "api v1/blocks/new1"*) echo '{"results":[{"type":"paragraph","id":"b1","paragraph":{"rich_text":[{"plain_text":"<!-- archivist-generated -->"}]}}],"has_more":false}' ;;
  "api v1/blocks/"*) echo '{"results":[{"type":"child_database","id":"db1","child_database":{"title":"KB Pages"}}]}' ;;
  "datasources resolve") echo '{"data_sources":[{"id":"ds1"}]}' ;;
  "api v1/data_sources/"*) echo '{"properties":{}}' ;;
  "api v1/pages") echo '{"id":"new1","url":"unew1"}' ;;
  "datasources query") echo "{\"results\":[$(row 1 'Billing overview'),$(row 2 'Refund rules')],\"has_more\":false,\"next_cursor\":null}" ;;
  *) echo "{}" ;;
esac
SH
chmod +x stub/ntn
