#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
# ./bq stands in for the BigQuery CLI: project novelglide holds analytics_123 (and
# an unrelated dataset) until ./nodataset exists. Each call is logged to bq.log on
# one line.
set -euo pipefail
mkdir -p .claude
printf 'vcs: git\nboard: file\nkb: docs/kb\ngate: dart test\nanalytics: novelglide\n' > .claude/assistant.md
cat > bq <<'JS'
#!/usr/bin/env node
const fs = require('fs');
const args = process.argv.slice(2);
fs.appendFileSync('bq.log', args.join(' ').replace(/\s+/g, ' ') + '\n');
const out = (o) => console.log(JSON.stringify(o));
if (args[0] === 'ls')
  out(fs.existsSync('nodataset') ? [] : [{ datasetReference: { datasetId: 'analytics_123' } }, { datasetReference: { datasetId: 'other' } }]);
else if (args[0] === 'query' && args.at(-1).includes('UNNEST'))
  out([{ param: 'book_id', types: ['string'], distinct_values: '40', events: '120', top: [{ value: 'b1', events: '9' }] }]);
else if (args[0] === 'query')
  out([{ event_name: 'book_open', events: '120', users: '14', first_day: '20261002', last_day: '20261030' },
    { event_name: 'session_start', events: '300', users: '20', first_day: '20261002', last_day: '20261030' }]);
else { console.error(`fake bq: unhandled ${args.join(' ')}`); process.exit(9); }
JS
chmod +x bq
