#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# `ntn` is a stand-in that keeps one page's body in ./page.md.
set -euo pipefail
mkdir -p .claude
printf 'vcs: git\nboard: notion\nnotion_root: abcdefabcdefabcdefabcdefabcdefab\ngate: dart test\n' > .claude/assistant.md
cat > ntn <<'JS'
#!/usr/bin/env node
const fs = require('fs');
const a = process.argv.slice(2).join(' ');
const id = '0123456789abcdef0123456789abcdef';
const body = () => (fs.existsSync('page.md') ? fs.readFileSync('page.md', 'utf8') : '');
const out = (o) => console.log(typeof o === 'string' ? o : JSON.stringify(o));
if (a.startsWith('api v1/blocks/abcdefabcdefabcdefabcdefabcdefab/children'))
  out({ results: [{ type: 'child_database', id: 'db1', child_database: { title: 'TaskList' } }] });
else if (a.startsWith('datasources resolve')) out({ data_sources: [{ id: 'ds1' }] });
else if (a.startsWith('api v1/data_sources/')) out({ properties: {} });
else if (a === 'api v1/pages -X POST') out({ id, url: `https://www.notion.so/${id}` });
else if (a.startsWith(`pages edit ${id}`)) fs.writeFileSync('page.md', fs.readFileSync(0, 'utf8'));
else if (a.startsWith(`api v1/blocks/${id}/children`))
  out({ results: body().split('\n').filter((l) => l.trim()).map((l) => ({ type: 'paragraph', paragraph: { rich_text: [{ plain_text: l }] } })), has_more: false });
else if (a.startsWith(`pages get ${id}`)) out(body());
else if (a.startsWith(`api v1/pages/${id}`)) out({ id });
else { console.error(`fake ntn: unhandled "${a}"`); process.exit(9); }
JS
chmod +x ntn
