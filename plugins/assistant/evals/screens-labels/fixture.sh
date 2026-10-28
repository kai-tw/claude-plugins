#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
set -euo pipefail
git init -q
mkdir -p .claude shots
touch .claude/assistant.md
# Parts joined by `__`: screen, size class, state, theme, locale. Two screens; one of them in two locales.
png=iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==
for n in step_wait__compact__starting step_wait__medium__starting account_unresolved__compact__failed; do
  for t in light dark; do base64 -d <<<"$png" > "shots/${n}__${t}__zh-TW.png"; done
done
for t in light dark; do base64 -d <<<"$png" > "shots/account_unresolved__compact__failed__${t}__en.png"; done
cat > shots/labels.json <<'J'
{"lang": "zh-Hant", "title": "啟動畫面審查",
 "screens": {"step_wait": "等待頁", "account_unresolved": "帳號無法確認頁"},
 "states": {"compact__starting": "手機：啟動中", "medium__starting": "平板：啟動中", "compact__failed": "手機：失敗"},
 "locales": {"zh-TW": "繁中", "en": "英文"}}
J
