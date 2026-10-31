#!/usr/bin/env node
// asst-analytics — the project's analytics events in BigQuery, read-only.
//
// Usage: asst-analytics events [--days N]           every event: events, users, first and last day
//        asst-analytics params <event> [--days N]   its parameters: types, distinct values, events, top 5 values
//        asst-analytics sql "<query>"               any SELECT; {events} stands for the export's events_* tables
//        asst-analytics --help
//
// The adapter's `analytics: <gcp-project>` names the project the Firebase / GA4
// daily export lands in; the dataset is its one analytics_<property> dataset.
// Days count back from yesterday (N days, default 28), since a day's table lands
// the day after. Every query caps bytes billed at 1 GB (ASST_ANALYTICS_MAX_BYTES
// overrides), so a query that would cost money fails instead.
// Output: a {op, project, dataset, count} line, then one JSON row per line.
// Exit 2 = no adapter entry, no dataset or bad arguments; bq failures pass through.
import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const fail = (m) => { console.error(`asst-analytics: ${m}`); process.exit(2); };
const args = process.argv.slice(2);
const [op] = args;
if (!op || op === '--help' || op === '-h') {
  const src = readFileSync(fileURLToPath(import.meta.url), 'utf8').split('\n');
  console.log(src.slice(1, src.findIndex((l, i) => i > 0 && !l.startsWith('//'))).join('\n').replace(/^\/\/ ?/gm, ''));
  process.exit(0);
}

const root = execFileSync('bash', [join(here, 'root.sh')], { encoding: 'utf8' }).trim();
const adapterPath = join(root, '.claude/assistant.md');
const adapter = existsSync(adapterPath) ? readFileSync(adapterPath, 'utf8') : '';
const project = adapter.match(/^analytics:[ \t]*([^#\n]*[^#\s])/m)?.[1] ?? '';
if (!project || project === 'none')
  fail(`the adapter has no analytics: <gcp-project> (${adapterPath}) — the project whose Firebase / GA4 BigQuery export holds the events.`);

const daysAt = args.indexOf('--days');
const days = daysAt < 0 ? 28 : Number(args[daysAt + 1]);
if (!Number.isInteger(days) || days < 1) fail('--days takes a whole number of days, 1 or more');
const rest = args.slice(1).filter((_, i) => i + 1 !== daysAt && i + 1 !== daysAt + 1);
const maxBytes = process.env.ASST_ANALYTICS_MAX_BYTES ?? String(1e9);

function bq(bqArgs) {
  const r = spawnSync('bq', bqArgs, { encoding: 'utf8', input: '', maxBuffer: 1 << 28 });
  if (r.error) fail(`bq: ${r.error.message} — install the Google Cloud SDK and run \`gcloud auth login\``);
  if (r.status !== 0) { process.stderr.write(r.stderr || r.stdout); process.exit(r.status); }
  const out = r.stdout.trim();
  return out ? JSON.parse(out) : [];
}

const datasets = bq(['ls', '--format=json', `--project_id=${project}`])
  .map((d) => d.datasetReference?.datasetId).filter((id) => /^analytics_\d+$/.test(id ?? ''));
if (datasets.length !== 1)
  fail(datasets.length
    ? `${project} has ${datasets.length} analytics datasets (${datasets.join(', ')}); name one with sql and \`${project}.<dataset>.events_*\`.`
    : `${project} has no analytics_<property> dataset yet. Link it in Firebase → Project settings → Integrations → BigQuery (daily export); the dataset appears the day after.`);
const dataset = datasets[0];
const table = `\`${project}.${dataset}.events_*\``;
const window = `_TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL ${days} DAY))
    AND FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))`;

let sql;
switch (op) {
  case 'events':
    sql = `SELECT event_name, COUNT(*) AS events, COUNT(DISTINCT user_pseudo_id) AS users,
  MIN(event_date) AS first_day, MAX(event_date) AS last_day
FROM ${table} WHERE ${window}
GROUP BY event_name ORDER BY events DESC`;
    break;
  case 'params': {
    const [event] = rest;
    if (!/^[A-Za-z][A-Za-z0-9_]*$/.test(event ?? '')) fail('params <event>: an event name — letters, digits and underscores');
    sql = `WITH v AS (
  SELECT p.key AS param,
    CASE WHEN p.value.string_value IS NOT NULL THEN 'string' WHEN p.value.int_value IS NOT NULL THEN 'int'
      WHEN p.value.double_value IS NOT NULL THEN 'double' WHEN p.value.float_value IS NOT NULL THEN 'float' ELSE 'null' END AS type,
    COALESCE(p.value.string_value, CAST(p.value.int_value AS STRING), CAST(p.value.double_value AS STRING), CAST(p.value.float_value AS STRING)) AS value,
    COUNT(*) AS events
  FROM ${table}, UNNEST(event_params) AS p
  WHERE event_name = '${event}' AND ${window}
  GROUP BY param, type, value),
r AS (SELECT *, ROW_NUMBER() OVER (PARTITION BY param ORDER BY events DESC) AS rn,
  COUNT(*) OVER (PARTITION BY param) AS distinct_values, SUM(events) OVER (PARTITION BY param) AS param_events FROM v)
SELECT param, ARRAY_AGG(DISTINCT type) AS types, MAX(distinct_values) AS distinct_values, MAX(param_events) AS events,
  ARRAY_AGG(STRUCT(value, events) ORDER BY events DESC) AS top
FROM r WHERE rn <= 5 GROUP BY param ORDER BY events DESC`;
    break;
  }
  case 'sql': {
    const [query] = rest;
    if (!query) fail('sql "<query>": a SELECT; {events} stands for the events_* tables');
    sql = query.replaceAll('{events}', table);
    break;
  }
  default: fail(`unknown op "${op}" (events · params · sql)`);
}

const rows = bq(['query', `--project_id=${project}`, '--use_legacy_sql=false', '--format=json', '--quiet',
  `--maximum_bytes_billed=${maxBytes}`, sql]);
console.log(JSON.stringify({ op, project, dataset, ...(op === 'sql' ? {} : { days }), count: rows.length }));
for (const r of rows) console.log(JSON.stringify(r));
