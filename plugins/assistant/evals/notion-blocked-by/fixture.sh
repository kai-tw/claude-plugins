#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# ./ntn stands in for the Notion CLI: a root holding a TaskList whose live schema has
# the Dependencies relation "Blocked by" only once ./deps exists. Writes are logged to
# ntn.log: POST and EDIT with their input. row.json is a Next row blocked by page a….
set -euo pipefail
printf '{"db":"tasklist","rows":[{"Name":"Upload retry","Status":"Next","Blocked by":["aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"]}]}\n' > row.json
cat > ntn <<'JS'
#!/usr/bin/env node
const fs = require('fs');
const a = process.argv.slice(2).join(' ');
const stdin = () => { try { return fs.readFileSync(0, 'utf8'); } catch { return ''; } };
const log = (s) => fs.appendFileSync('ntn.log', s + '\n');
const out = (o) => console.log(typeof o === 'string' ? o : JSON.stringify(o));
const created = 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
const body = () => (fs.existsSync('page.md') ? fs.readFileSync('page.md', 'utf8') : '');
if (a.startsWith('api v1/blocks/abcdefabcdefabcdefabcdefabcdefab/children'))
  out({ results: [{ type: 'child_database', id: 'db1', child_database: { title: 'TaskList' } }] });
else if (a.startsWith('datasources resolve')) out({ data_sources: [{ id: 'ds1' }] });
else if (a.startsWith('api v1/data_sources/'))
  out({ properties: fs.existsSync('deps') ? { 'Blocked by': { type: 'relation', relation: { data_source_id: 'ds1', type: 'dual_property' } } } : {} });
else if (a === 'api v1/pages -X POST') { log(`POST ${stdin()}`); out({ id: created, url: `https://www.notion.so/${created}` }); }
else if (a.startsWith(`pages edit ${created}`)) { const s = stdin(); log(`EDIT ${JSON.stringify(s)}`); fs.writeFileSync('page.md', s); }
else if (a.startsWith(`api v1/blocks/${created}/children`))
  out({ results: body().split('\n').filter((l) => l.trim()).map((l) => ({ type: 'paragraph', paragraph: { rich_text: [{ plain_text: l }] } })), has_more: false });
else { console.error(`fake ntn: unhandled "${a}"`); process.exit(9); }
JS
chmod +x ntn
