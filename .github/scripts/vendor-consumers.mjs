#!/usr/bin/env node
// Read .github/vendor-consumers.yml and emit it as JSON for a workflow matrix.
//
// A restricted parser rather than a YAML dependency: the file is a fixed shape
// (one `consumers:` list of three scalar keys), and every deviation from that
// shape is a hard error here. A general parser would silently accept a
// misspelled key and hand the workflow a consumer with `undefined` for a path.
//
// Usage: node .github/scripts/vendor-consumers.mjs [--repo <owner/name>]

import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const file = join(root, '.github', 'vendor-consumers.yml');

const die = (msg) => {
  console.error(`vendor-consumers: ${msg}`);
  process.exit(1);
};

const KEYS = new Set(['repo', 'path', 'base']);
const lines = readFileSync(file, 'utf8').split(/\r?\n/);

const consumers = [];
let seenHeader = false;
let current = null;

for (const [i, raw] of lines.entries()) {
  const at = `${file}:${i + 1}`;
  const line = raw.replace(/\s+$/, '');
  if (line === '' || /^\s*#/.test(line)) continue;

  if (line === 'consumers:') {
    if (seenHeader) die(`${at}: a second "consumers:" key`);
    seenHeader = true;
    continue;
  }
  if (!seenHeader) die(`${at}: content before "consumers:" — ${JSON.stringify(line)}`);

  const item = line.match(/^ {2}- ([a-z]+): (\S.*)$/);
  if (item) {
    if (current) consumers.push(current);
    current = {};
  }
  const kv = item ?? line.match(/^ {4}([a-z]+): (\S.*)$/);
  if (!kv) die(`${at}: not a recognised entry line — ${JSON.stringify(line)}`);
  if (!current) die(`${at}: a key outside any list item`);

  const [, key, value] = kv;
  if (!KEYS.has(key)) die(`${at}: unknown key ${JSON.stringify(key)} (expected ${[...KEYS].join(', ')})`);
  if (key in current) die(`${at}: duplicate key ${JSON.stringify(key)} in one consumer`);
  current[key] = value.replace(/^(['"])(.*)\1$/, '$2');
}
if (current) consumers.push(current);

if (consumers.length === 0) die('no consumers listed');
for (const c of consumers) {
  for (const k of KEYS) if (!c[k]) die(`consumer ${JSON.stringify(c.repo ?? '?')} is missing "${k}"`);
  const m = c.repo.match(/^([\w.-]+)\/([\w.-]+)$/);
  if (!m) die(`consumer repo ${JSON.stringify(c.repo)} is not owner/name`);
  // Split here rather than in the workflow: a GitHub expression has no string
  // split, and the App installation is addressed by owner.
  [, c.owner, c.name] = m;
  // A path that escapes the consumer checkout would have the sync write outside
  // the repo — refuse it here rather than discovering it as a mysterious diff.
  if (c.path.startsWith('/') || c.path.split('/').includes('..')) {
    die(`consumer ${c.repo}: path ${JSON.stringify(c.path)} must be repo-relative with no ".." segment`);
  }
}

const only = process.argv.includes('--repo') ? process.argv[process.argv.indexOf('--repo') + 1] : undefined;
const selected = only ? consumers.filter((c) => c.repo === only) : consumers;
if (only && selected.length === 0) die(`no consumer named ${JSON.stringify(only)}`);

console.log(JSON.stringify(selected));
