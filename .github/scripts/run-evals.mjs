#!/usr/bin/env node
// Run the evals of every plugin that changed, and fail when a change is not
// covered by them.
//
// `validate.mjs` and `check-version-bump.mjs` prove a release is well-formed,
// not that it works — before this ran, a plugin could ship a broken script on
// every commit and CI stayed green. Three ways to fail here:
//   • a suite fails;
//   • a suite passes having graded nothing (no case, or no regex grader) — an
//     empty suite exits 0 exactly like a clean one;
//   • a changed plugin carries code (libexec/, its own hooks, a scripts/ dir) but no
//     evals/run.sh. Plugins that have none are only held to this when they are
//     next changed, so the rule ratchets instead of reddening CI all at once.
//
// Usage: node .github/scripts/run-evals.mjs [--base <ref>] [plugin …]
//   plugin names given → exactly those; otherwise every plugin changed since
//   <ref> (default HEAD^), committed or not.

import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, readdirSync, statSync } from 'node:fs';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const git = (...args) =>
  execFileSync('git', args, { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();

const argv = process.argv.slice(2);
let base = 'HEAD^';
const named = [];
for (let i = 0; i < argv.length; i++) {
  if (argv[i] === '--base') base = argv[++i];
  else named.push(argv[i]);
}

const pluginsDir = join(root, 'plugins');
const all = readdirSync(pluginsDir).filter((n) => statSync(join(pluginsDir, n)).isDirectory());

let targets;
if (named.length) {
  const unknown = named.filter((n) => !all.includes(n));
  if (unknown.length) {
    console.error(`✘ no such plugin: ${unknown.join(', ')}`);
    process.exit(1);
  }
  targets = named;
} else {
  let changed;
  try {
    git('rev-parse', '--verify', `${base}^{commit}`);
    changed = `${git('diff', '--name-only', `${base}...HEAD`)}\n${git('diff', '--name-only', 'HEAD')}`;
  } catch {
    console.log(`ℹ no base commit (${base}) — nothing to compare, skipping`);
    process.exit(0);
  }
  const names = new Set(changed.split('\n').map((f) => f.match(/^plugins\/([^/]+)\//)?.[1]).filter(Boolean));
  targets = all.filter((n) => names.has(n));
}

if (!targets.length) {
  console.log('✔ no plugin changed — no evals to run');
  process.exit(0);
}

// stale-check.sh and path.sh are the same file in every plugin, so a plugin whose only hook
// they are carries no code of its own.
const sharedHooks = new Set(['hooks.json', 'stale-check.sh', 'path.sh']);
const hasCode = (dir) => {
  if (existsSync(join(dir, 'libexec'))) return true;
  const hooks = join(dir, 'hooks');
  if (existsSync(hooks) && readdirSync(hooks).some((n) => !sharedHooks.has(n))) return true;
  const walk = (d) =>
    readdirSync(d).some((n) => {
      const p = join(d, n);
      if (!statSync(p).isDirectory()) return false;
      return n === 'scripts' || (n !== 'evals' && n !== 'node_modules' && walk(p));
    });
  return walk(dir);
};

const errors = [];
for (const name of targets) {
  const dir = join(pluginsDir, name);
  const runner = join(dir, 'evals/run.sh');
  if (!existsSync(runner)) {
    if (hasCode(dir)) {
      errors.push(`${name}: changed and carries code, but has no evals/run.sh — add a case that exercises the change`);
    } else {
      console.log(`ℹ ${name}: no code, no evals — skipped`);
    }
    continue;
  }
  console.log(`\n── ${name}`);
  const r = spawnSync('bash', [runner], { cwd: root, encoding: 'utf8' });
  const out = `${r.stdout ?? ''}${r.stderr ?? ''}`;
  process.stdout.write(out);
  const passed = (out.match(/^PASS /gm) ?? []).length;
  if (r.status !== 0) errors.push(`${name}: evals failed (exit ${r.status})`);
  else if (passed === 0) errors.push(`${name}: evals/run.sh exited 0 but graded nothing`);
}

if (errors.length) {
  console.error(`\n✘ ${errors.length} plugin(s) not covered by passing evals:\n`);
  for (const e of errors) console.error(`  • ${e}`);
  process.exit(1);
}
console.log(`\n✔ evals passed: ${targets.join(', ')}`);
