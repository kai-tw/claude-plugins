#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# ./ntn stands in for the Notion CLI: under the root sit TaskList (ds1), KB Pages
# (ds2: "Read aloud" a…, "Human voice" b…, and two rows titled "Dup") and the
# Decision Log (ds3, with the Pages and Task relations). It only answers reads.
set -euo pipefail
row='"Context":"c","Decision":"d","Consequence":"e","Status":"Active","Task":"cccccccccccccccccccccccccccccccc"'
printf '{"db":"decision-log","rows":[{"Name":"voice pick","Pages":["Read aloud","Human voice"],%s}]}\n' "$row" > ok.json
printf '{"db":"decision-log","rows":[{"Name":"voice pick","Pages":["Nope"],%s}]}\n' "$row" > missing.json
printf '{"db":"decision-log","rows":[{"Name":"voice pick","Pages":["Dup"],%s}]}\n' "$row" > dup.json
cat > ntn <<'JS'
#!/usr/bin/env node
const a = process.argv.slice(2).join(' ');
const out = (o) => console.log(JSON.stringify(o));
const id = (c) => `${c.repeat(8)}-${c.repeat(4)}-${c.repeat(4)}-${c.repeat(4)}-${c.repeat(12)}`;
const page = (c, name) => ({ id: id(c), url: `u${c}`, properties: { Name: { type: 'title', title: [{ plain_text: name }] } } });
const rel = (ds) => ({ type: 'relation', relation: { data_source_id: ds, type: 'single_property' } });
if (a.startsWith('api v1/blocks/abcdefabcdefabcdefabcdefabcdefab/children'))
  out({ results: [['db1', 'TaskList'], ['db2', 'KB Pages'], ['db3', 'Decision Log']]
    .map(([id, title]) => ({ type: 'child_database', id, child_database: { title } })) });
else if (a.startsWith('datasources resolve db')) out({ data_sources: [{ id: `ds${a.split(' ')[2].slice(2)}` }] });
else if (a.startsWith('api v1/data_sources/ds3')) out({ properties: { Pages: rel('ds2'), Task: rel('ds1') } });
else if (a.startsWith('api v1/data_sources/ds2'))
  out({ properties: { Module: { type: 'select', select: { options: [{ name: 'Product' }] } }, Kind: { type: 'select', select: { options: [{ name: 'Feature' }] } } } });
else if (a.startsWith('api v1/data_sources/')) out({ properties: {} });
else if (a.startsWith('datasources query ds2'))
  out({ results: [page('a', 'Read aloud'), page('b', 'Human voice'), page('d', 'Dup'), page('e', 'Dup')], has_more: false, next_cursor: null });
else { console.error(`fake ntn: unhandled "${a}"`); process.exit(9); }
JS
chmod +x ntn
