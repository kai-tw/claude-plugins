#!/usr/bin/env node
// Filter package-relative paths (stdin, one a line) through the `mutate` list of
// the package's Stryker config, the way Stryker reads it: patterns in order, a
// `!` pattern drops what earlier ones took, a `file:start-end` range counts as
// its file. plan-mutation passes `--mutate` itself, which replaces the config's
// list, so without this a file the config leaves out would be mutated anyway.
// Usage: node stryker_mutate.mjs <package dir> < paths
// Exit: 0 kept paths on stdout · 3 no config or no `mutate` list · 2 unreadable config
import { existsSync, readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const pkg = path.resolve(process.argv[2] ?? '.');
// Stryker's own search order (SUPPORTED_CONFIG_FILE_NAMES in @stryker-mutator/core).
const names = ['', '.'].flatMap(p => ['.conf', '.config'].flatMap(s =>
  ['json', 'js', 'mjs', 'cjs'].map(e => `${p}stryker${s}.${e}`)));
const name = names.find(n => existsSync(path.join(pkg, n)));
if (!name) process.exit(3);
const file = path.join(pkg, name);

let options;
try {
  if (name.endsWith('.json')) options = JSON.parse(readFileSync(file, 'utf8'));
  else options = (await import(pathToFileURL(file).href)).default;
} catch (err) {
  console.error(`plan-mutation: cannot read ${path.relative(process.cwd(), file)} for its \`mutate\` list: ${err.message}`);
  process.exit(2);
}
const patterns = options?.mutate;
if (!Array.isArray(patterns) || patterns.length === 0) process.exit(3);

// Stryker's matcher is minimatch on resolved paths, with dot files allowed.
let match;
try {
  const core = createRequire(path.join(pkg, 'package.json')).resolve('@stryker-mutator/core/package.json');
  const { minimatch } = createRequire(core)('minimatch');
  match = (f, p) => minimatch(f, p, { dot: true });
} catch {
  process.emitWarning = () => {};   // path.matchesGlob is experimental on some Node versions
  match = (f, p) => path.matchesGlob(f, p);
}
const RANGE = /(.*?):((\d+)(?::(\d+))?-(\d+)(?::(\d+))?)$/;   // Stryker's MUTATION_RANGE_REGEX
const norm = (p) => path.resolve(pkg, p).split(path.sep).join('/');

const kept = new Set();
const rels = readFileSync(0, 'utf8').split('\n').filter(Boolean);
for (const raw of patterns) {
  const neg = raw.startsWith('!');
  const glob = norm((neg ? raw.slice(1) : raw).replace(RANGE, '$1'));
  for (const r of rels) if (match(norm(r), glob)) neg ? kept.delete(r) : kept.add(r);
}
for (const r of rels) if (kept.has(r)) console.log(r);
