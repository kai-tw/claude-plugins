#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# ./ntn stands in for the Notion CLI. Its TaskList holds four rows: A (In Progress),
# B (Next, blocked by A), C (Next, blocked by A and D) and D (Backlog). The live
# schema has the Dependencies relation "Blocked by" only once ./deps exists.
# Writes are logged to ntn.log: POST and EDIT with their input, PATCH <id> <input>,
# TRASH <id>.
set -euo pipefail
mkdir -p .claude
printf 'vcs: git\nboard: notion\nnotion_root: abcdefabcdefabcdefabcdefabcdefab\ngate: dart test\n' > .claude/assistant.md
printf 'Found while building A.\n' > found.md
cat > ntn <<'JS'
#!/usr/bin/env node
const fs = require('fs');
const a = process.argv.slice(2).join(' ');
const stdin = () => { try { return fs.readFileSync(0, 'utf8'); } catch { return ''; } };
const log = (s) => fs.appendFileSync('ntn.log', s + '\n');
const out = (o) => console.log(typeof o === 'string' ? o : JSON.stringify(o));
const id = (c) => `${c.repeat(8)}-${c.repeat(4)}-${c.repeat(4)}-${c.repeat(4)}-${c.repeat(12)}`;
const created = 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
const row = (c, name, status, blockedBy) => ({ id: id(c), url: `u${c}`, properties: {
  Name: { type: 'title', title: [{ plain_text: name }] },
  Status: { type: 'select', select: { name: status } },
  Stage: { type: 'select', select: { name: 'Review' } },
  'Blocked by': { type: 'relation', relation: blockedBy.map((b) => ({ id: id(b) })) } } });
const body = () => (fs.existsSync('page.md') ? fs.readFileSync('page.md', 'utf8') : '');
if (a.startsWith('api v1/blocks/abcdefabcdefabcdefabcdefabcdefab/children'))
  out({ results: [{ type: 'child_database', id: 'db1', child_database: { title: 'TaskList' } }] });
else if (a.startsWith('datasources resolve')) out({ data_sources: [{ id: 'ds1' }] });
else if (a.startsWith('api v1/data_sources/'))
  out({ properties: fs.existsSync('deps') ? { 'Blocked by': { type: 'relation', relation: { data_source_id: 'ds1', type: 'dual_property' } } } : {} });
else if (a.startsWith('datasources query'))
  out({ results: [row('a', 'Blocker', 'In Progress', []), row('b', 'Waits on A', 'Next', ['a']),
    row('c', 'Waits on A and D', 'Next', ['a', 'd']), row('d', 'Other', 'Backlog', [])], has_more: false, next_cursor: null });
else if (a === 'api v1/pages -X POST') { log(`POST ${stdin()}`); out({ id: created, url: `https://www.notion.so/${created}` }); }
else if (a.startsWith(`pages edit ${created}`)) { const s = stdin(); log(`EDIT ${JSON.stringify(s)}`); fs.writeFileSync('page.md', s); }
else if (a.startsWith(`api v1/blocks/${created}/children`))
  out({ results: body().split('\n').filter((l) => l.trim()).map((l) => ({ type: 'paragraph', paragraph: { rich_text: [{ plain_text: l }] } })), has_more: false });
else if (/^api v1\/pages\/\S+ -X PATCH/.test(a)) { log(`PATCH ${a.split(' ')[1].slice('v1/pages/'.length)} ${stdin()}`); out({}); }
else if (a.startsWith('pages get ')) out('<!-- archivist-generated -->');
else if (a.startsWith('pages trash ')) { log(`TRASH ${a.split(' ')[2]}`); out({}); }
else { console.error(`fake ntn: unhandled "${a}"`); process.exit(9); }
JS
chmod +x ntn
