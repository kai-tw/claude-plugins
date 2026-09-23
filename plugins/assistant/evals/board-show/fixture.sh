#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# notion/ uses stub/ntn, which answers one page (properties, and its body for
# `pages get`) and logs every call; file/ holds a local board with one row and
# its filed brief.
set -euo pipefail
git init -q
mkdir -p notion/.claude file/.claude/.assistant/tasks/t1 stub
printf 'board: notion\nnotion_root: 11111111111111111111111111111111\n' > notion/.claude/assistant.md
printf 'board: file\nkb: docs\n' > file/.claude/assistant.md
cat > file/.claude/.assistant/board.md <<'MD'
| Slug | Name | Status | Stage | Trigger |
|---|---|---|---|---|
| t1 | Local task | In Progress | Review |  |
MD
printf '## 意圖\nthe local brief\n' > file/.claude/.assistant/tasks/t1/brief.md
cat > stub/ntn <<'SH'
#!/usr/bin/env bash
echo "$*" >> "$EVAL_WS/ntn.log"
case "$1 $2" in
  "api v1/pages/"*) echo '{"object":"page","id":"p9","url":"u9","properties":{"Name":{"type":"title","title":[{"plain_text":"Remote task"}]},"Status":{"type":"status","status":{"name":"Next"}},"Trigger":{"type":"rich_text","rich_text":[]}}}' ;;
  "pages get") printf '## 系統設計\nthe remote brief\n' ;;
  *) echo '{}' ;;
esac
SH
chmod +x stub/ntn
