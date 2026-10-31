#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# ./ntn stands in for the Notion CLI. Its TaskList holds D (the parent, In Progress),
# A (sub-item of D, In Progress) and B (sub-item of D, Next, blocked by A). A trashed
# page leaves later queries (trashed.txt). Writes are logged to ntn.log: POST with
# its input, PATCH <id> <input>, TRASH <id>.
set -euo pipefail
mkdir -p .claude
printf 'vcs: git\nboard: notion\nnotion_root: abcdefabcdefabcdefabcdefabcdefab\ngate: dart test\n' > .claude/assistant.md
cat > ntn <<'JS'
#!/usr/bin/env node
const fs = require('fs');
const a = process.argv.slice(2).join(' ');
const stdin = () => { try { return fs.readFileSync(0, 'utf8'); } catch { return ''; } };
const log = (s) => fs.appendFileSync('ntn.log', s + '\n');
const out = (o) => console.log(typeof o === 'string' ? o : JSON.stringify(o));
const id = (c) => `${c.repeat(8)}-${c.repeat(4)}-${c.repeat(4)}-${c.repeat(4)}-${c.repeat(12)}`;
const trashed = () => (fs.existsSync('trashed.txt') ? fs.readFileSync('trashed.txt', 'utf8') : '');
const created = 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
const row = (c, name, status, blockedBy, parent) => ({ id: id(c), url: `u${c}`, properties: {
  Name: { type: 'title', title: [{ plain_text: name }] },
  Status: { type: 'select', select: { name: status } },
  Stage: { type: 'select', select: { name: 'Review' } },
  'Blocked by': { type: 'relation', relation: blockedBy.map((b) => ({ id: id(b) })) },
  'Parent item': { type: 'relation', relation: parent ? [{ id: id(parent) }] : [] } } });
const rel = { type: 'relation', relation: { data_source_id: 'ds1', type: 'dual_property' } };
if (a.startsWith('api v1/blocks/abcdefabcdefabcdefabcdefabcdefab/children'))
  out({ results: [{ type: 'child_database', id: 'db1', child_database: { title: 'TaskList' } }] });
else if (a.startsWith('datasources resolve')) out({ data_sources: [{ id: 'ds1' }] });
else if (a.startsWith('api v1/data_sources/')) out({ properties: { 'Blocked by': rel, 'Parent item': rel } });
else if (a.startsWith('datasources query'))
  out({ results: [row('d', 'Sync rework', 'In Progress', [], null), row('a', 'Sync schema', 'In Progress', [], 'd'),
    row('b', 'Sync UI', 'Next', ['a'], 'd')].filter((r) => !trashed().includes(r.id.replace(/-/g, ''))), has_more: false, next_cursor: null });
else if (a === 'api v1/pages -X POST') { log(`POST ${stdin()}`); out({ id: created, url: `https://www.notion.so/${created}` }); }
else if (a.startsWith(`pages edit ${created}`)) stdin();
else if (a.startsWith(`api v1/blocks/${created}/children`)) out({ results: [], has_more: false });
else if (/^api v1\/pages\/\S+ -X PATCH/.test(a)) { log(`PATCH ${a.split(' ')[1].slice('v1/pages/'.length)} ${stdin()}`); out({}); }
else if (a.startsWith('pages get ')) out('<!-- archivist-generated -->');
else if (a.startsWith('pages trash ')) { const t = a.split(' ')[2].replace(/-/g, ''); log(`TRASH ${t}`); fs.appendFileSync('trashed.txt', t + '\n'); out({}); }
else { console.error(`fake ntn: unhandled "${a}"`); process.exit(9); }
JS
chmod +x ntn
