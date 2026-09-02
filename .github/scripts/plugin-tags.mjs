#!/usr/bin/env node
// Tag every plugin whose manifest version has no tag yet.
//
// THE ONLY THING THAT TAGS. Nothing tags by hand — `release.mjs` deliberately
// does not, and a cloud session cannot (the GitHub authorization there refuses
// a tag push with a 403). An untagged version is not a cosmetic gap: the tag is
// what `vendor-sync` ships from, so the consumers keep serving the previous
// release and nothing anywhere says so.
//
// It only ever ADDS a tag, never moves one: a moved tag would let one version
// number mean two different trees, which is the failure `.claude/rules/
// releasing.md` opens with.
//
// Usage: node .github/scripts/plugin-tags.mjs [--create]
//   (default)  print the plan, change nothing
//   --create   create the annotated tags at HEAD — does NOT push
// Writes `tags=<space separated>` to $GITHUB_OUTPUT when that variable is set.

import { execFileSync } from 'node:child_process';
import { appendFileSync, existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const git = (...args) => execFileSync('git', args, { cwd: root, encoding: 'utf8' }).trim();
// Probing for a tag that may not exist is the normal case here; silence git's
// stderr so an expected miss does not leave a `fatal:` in the log that reads
// like a real failure.
const gitOrNull = (...args) => {
  try {
    return execFileSync('git', args, { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
  } catch {
    return null;
  }
};

const create = process.argv.includes('--create');

// Only plain x.y.z. A pre-release would have to answer "does 1.0.0-rc.2 outrank
// 1.0.0?" and this repo has never had one — refusing is honest, guessing an
// order silently is not.
const SEMVER = /^(\d+)\.(\d+)\.(\d+)$/;
const parse = (v) => {
  const m = SEMVER.exec(v ?? '');
  return m ? [Number(m[1]), Number(m[2]), Number(m[3])] : null;
};
const cmp = (a, b) => a[0] - b[0] || a[1] - b[1] || a[2] - b[2];

const pluginsDir = join(root, 'plugins');
const errors = [];
const planned = [];

for (const name of readdirSync(pluginsDir).sort()) {
  if (!statSync(join(pluginsDir, name)).isDirectory()) continue;
  const manifest = join(pluginsDir, name, '.claude-plugin', 'plugin.json');
  if (!existsSync(manifest)) continue;

  const version = JSON.parse(readFileSync(manifest, 'utf8')).version;
  if (!parse(version)) {
    errors.push(`${name}: version "${version}" is not x.y.z — this script will not guess how it orders`);
    continue;
  }

  const tag = `${name}--v${version}`;
  if (gitOrNull('rev-parse', '--verify', `refs/tags/${tag}`)) {
    console.log(`✔ ${name} ${version} — already tagged`);
    continue;
  }

  // Refuse to go backwards. A manifest below the newest tag means someone
  // reverted a bump, and tagging HEAD would attach an older number to a newer
  // tree — the same "one version, two trees" failure from the other direction.
  const newest = (gitOrNull('tag', '-l', `${name}--v*`) || '')
    .split('\n')
    .filter(Boolean)
    .map((t) => parse(t.slice(`${name}--v`.length)))
    .filter(Boolean)
    .sort(cmp)
    .pop();

  if (newest && cmp(parse(version), newest) <= 0) {
    errors.push(
      `${name}: manifest is at ${version}, but ${name}--v${newest.join('.')} is already tagged\n` +
        `      → bump plugins/${name}/.claude-plugin/plugin.json above the newest tag`,
    );
    continue;
  }

  planned.push({ name, version, tag });
  console.log(`→ ${name} ${version} — ${newest ? `newer than ${newest.join('.')}, ` : 'first release, '}will tag ${tag}`);
}

if (errors.length) {
  console.error(`\n✘ ${errors.length} plugin(s) cannot be tagged:\n`);
  for (const e of errors) console.error(`  • ${e}\n`);
  process.exit(1);
}

if (create) {
  for (const { name, version, tag } of planned) {
    git('tag', '-a', tag, '-m', `${name} ${version}\n\n由 plugin-tag workflow 依 plugin.json 自動建立。`);
    console.log(`  tagged ${tag} at ${git('rev-parse', '--short', 'HEAD')}`);
  }
}

if (process.env.GITHUB_OUTPUT) {
  appendFileSync(process.env.GITHUB_OUTPUT, `tags=${planned.map((p) => p.tag).join(' ')}\n`);
}

console.log(planned.length ? `\n${planned.length} tag(s) ${create ? 'created' : 'to create'}` : '\nnothing to tag');
