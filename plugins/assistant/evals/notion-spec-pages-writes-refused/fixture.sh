#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# stub/ntn stands in for the Notion CLI: one KB root holding KB Pages and TaskList. Page p1
# sits in the KB Pages data source (a spec page), p2 under a plain page, and a
# lookup of pe answers with a Notion error object at exit 0. Any call that would
# write (a POST, a PATCH, `pages edit`, `pages trash`) is logged as "write …" in
# ntn.log, so a write that is let through shows up there.
set -euo pipefail
git init -q
mkdir -p stub
: > ntn.log
printf '{"db":"tasklist","rows":[{"page_id":"p1","Name":"x"}]}' > update1.json
printf '{"db":"tasklist","rows":[{"page_id":"p2","Name":"x"}]}' > update2.json
printf '{"db":"tasklist","rows":[{"page_id":"pe","Name":"x"}]}' > updatee.json
cat > stub/ntn <<'SH'
#!/usr/bin/env bash
case "$*" in
  *"-X POST"*|*"-X PATCH"*|"pages edit"*|"pages trash"*) echo "write $*" >> "$EVAL_WS/ntn.log" ;;
esac
case "$1 $2" in
  "api v1/pages/p1") echo '{"object":"page","id":"p1","parent":{"type":"data_source_id","data_source_id":"ds1"}}' ;;
  "api v1/pages/p2") echo '{"object":"page","id":"p2","parent":{"type":"page_id","page_id":"root1"}}' ;;
  "api v1/pages/pe") echo '{"object":"error","status":429,"code":"rate_limited","message":"slow down"}' ;;
  "api v1/blocks/p"*) echo '{"results":[{"type":"paragraph","id":"b1","paragraph":{"rich_text":[{"plain_text":"<!-- archivist-generated -->"}]}}],"has_more":false}' ;;
  "api v1/blocks/"*) echo '{"results":[{"type":"child_database","id":"db1","child_database":{"title":"KB Pages"}},{"type":"child_database","id":"db2","child_database":{"title":"TaskList"}}],"has_more":false}' ;;
  "datasources resolve") if [ "$3" = db2 ]; then echo '{"data_sources":[{"id":"ds2"}]}'; else echo '{"data_sources":[{"id":"ds1"}]}'; fi ;;
  "api v1/data_sources/ds2") echo '{"title":[{"plain_text":"TaskList"}],"properties":{"Name":{"type":"title"}}}' ;;
  "api v1/data_sources/"*) echo '{"title":[{"plain_text":"KB Pages"}],"properties":{}}' ;;
  "api v1/comments") echo '{"id":"c1"}' ;;
  *) echo "{}" ;;
esac
SH
chmod +x stub/ntn
