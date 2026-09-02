#!/usr/bin/env node
// A plugin whose files changed must also change its version.
//
// Installs are cached per version under ~/.claude/plugins/cache/<marketplace>/
// <plugin>/<version>/. If content changes while the version stays put, the
// installer compares versions, sees no difference, and serves the stale copy
// forever — including from a *directory* marketplace, where it is tempting to
// assume edits are picked up live. They are not.
//
// This was not hypothetical: a skill was added to dart-lsp at 1.0.0 without a
// bump, and the next session verified that the plugin shipped without it.
//
// Usage: node .github/scripts/check-version-bump.mjs [baseRef]

import { execFileSync } from 'node:child_process';
import { existsSync, readdirSync, statSync } from 'node:fs';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const git = (...args) => execFileSync('git', args, { cwd: root, encoding: 'utf8' }).trim();
// Probing for something that may not exist is normal here (a missing base
// commit, an untagged version). Silence git's stderr so an expected miss does
// not leave a stray `fatal:` in the CI log looking like a real failure.
const gitOrNull = (...args) => {
  try {
    return execFileSync('git', args, {
      cwd: root,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  } catch {
    return null;
  }
};

const base = process.argv[2] || 'HEAD^';
if (!gitOrNull('rev-parse', '--verify', `${base}^{commit}`)) {
  console.log(`ℹ no base commit (${base}) — nothing to compare, skipping`);
  process.exit(0);
}

const versionAt = (ref, path) => {
  const text = gitOrNull('show', `${ref}:${path}`);
  if (text === null) return null; // did not exist at that ref
  try {
    return JSON.parse(text).version ?? null;
  } catch {
    return null;
  }
};

const pluginsDir = join(root, 'plugins');
if (!existsSync(pluginsDir)) {
  console.log('ℹ no plugins/ directory');
  process.exit(0);
}

const errors = [];

for (const name of readdirSync(pluginsDir)) {
  const dir = join(pluginsDir, name);
  if (!statSync(dir).isDirectory()) continue;

  const manifestRel = `plugins/${name}/.claude-plugin/plugin.json`;
  if (!existsSync(join(root, manifestRel))) continue;

  const changed = git('diff', '--name-only', `${base}...HEAD`, '--', `plugins/${name}/`)
    .split('\n')
    .filter(Boolean);
  if (changed.length === 0) continue;

  const before = versionAt(base, manifestRel);
  const after = versionAt('HEAD', manifestRel);

  if (before === null) {
    console.log(`✔ ${name}: new plugin at ${after}`);
    continue;
  }

  if (before === after) {
    errors.push(
      `${name}: ${changed.length} file(s) changed but version stayed at ${after}\n` +
        changed.map((f) => `      ${f}`).join('\n') +
        `\n      → installs are cached per version; bump it or nobody receives this change`,
    );
  } else {
    console.log(`✔ ${name}: ${before} → ${after} (${changed.length} file(s) changed)`);
    // Informational. The tag is created by .github/workflows/plugin-tag.yml
    // once this commit is on main, so an untagged version here is the normal
    // state on a pull request rather than something to act on.
    if (!gitOrNull('rev-parse', '--verify', `refs/tags/${name}--v${after}`)) {
      console.log(`  ↳ not tagged yet — plugin-tag will tag it when this lands on main`);
    }
  }
}

if (errors.length) {
  console.error(`\n✘ ${errors.length} plugin(s) changed without a version bump:\n`);
  for (const e of errors) console.error(`  • ${e}\n`);
  process.exit(1);
}

console.log('✔ version bump check passed');
