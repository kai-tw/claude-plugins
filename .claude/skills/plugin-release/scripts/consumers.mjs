// Once a version is on the default branch: refresh the marketplace index, update
// EVERY install of the plugin, then verify each one. Shared by release.mjs (run on
// the default branch) and after-merge.mjs.
//
// Every install, not the one the cwd resolves to: each project scope is its own
// install, and `claude plugin update` reaches only the project it runs in — one
// release printed all green while another consumer sat two versions behind.

import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const home = process.env.HOME;
// A missing cwd makes execFileSync report `spawnSync <cmd> ENOENT`, which reads
// as a missing command; an install record outlives a deleted project, so say that.
const run = (cmd, args, cwd) => {
  if (cwd && !existsSync(cwd)) {
    throw new Error(`${cwd} no longer exists — a stale install record; delete its entries from ~/.claude/plugins/installed_plugins.json`);
  }
  return execFileSync(cmd, args, { cwd, encoding: 'utf8' }).trim();
};
const errText = (e) => (e.stderr || e.stdout || e.message).trim();

// Where `marketplace` installs from; null when this machine has no such
// marketplace. The recorded shape differs per source kind — `{source:'git', url}`,
// `{source:'github', repo}`, `{source:'directory', path}` — so callers compare on
// the owner/repo `slug`, which all three can produce.
export function marketplaceSource(marketplace) {
  const p = join(home, '.claude/plugins/known_marketplaces.json');
  return existsSync(p) ? JSON.parse(readFileSync(p, 'utf8'))[marketplace]?.source ?? {} : null;
}
export const slug = (s) => String(s ?? '').replace(/^.*github\.com[/:]/, '').replace(/\.git$/, '');

export const installs = (id) => {
  const p = join(home, '.claude/plugins/installed_plugins.json');
  return existsSync(p) ? JSON.parse(readFileSync(p, 'utf8')).plugins?.[id] ?? [] : [];
};

const list = (dir, base = dir) =>
  readdirSync(dir).flatMap((n) => {
    if (n === '.in_use' || n === '.orphaned_at' || n === '.DS_Store') return [];
    const p = join(dir, n);
    return statSync(p).isDirectory() ? list(p, base) : [relative(base, p)];
  });

// Update every install of `plugin` to `version`, whose files are
// `git ls-tree <ref> plugins/<plugin>` in `root`. Returns the failures, one line
// each; an empty array means every install is at `version`, complete and loading.
export function updateConsumers({ root, marketplace, plugin, version, ref, log = console.log }) {
  const id = `${plugin}@${marketplace}`;
  const failures = [];
  // Refresh first: `update` compares against the index it already holds, so
  // without this it truthfully answers "already at the latest version" with the
  // OLD number.
  try {
    run('claude', ['plugin', 'marketplace', 'update', marketplace], root);
  } catch (e) {
    return [`marketplace refresh failed — ${errText(e)}`];
  }
  const all = installs(id);
  if (all.length === 0) {
    log(`  ⚠ ${id} is installed nowhere on this machine — nothing to update or verify`);
    return failures;
  }

  for (const i of all) {
    const where = i.projectPath ?? '~';
    try {
      log(`  ${where} [${i.scope}]: ${run('claude', ['plugin', 'update', id, '--scope', i.scope], i.projectPath ?? home).split('\n').pop()}`);
    } catch (e) {
      failures.push(`${where} [${i.scope}]: update failed — ${errText(e)}`);
    }
  }

  // Version: read back from the registry, not from update's exit code — `install`
  // on an installed plugin says `already installed` and changes nothing.
  for (const i of installs(id)) {
    if (i.version !== version) failures.push(`${i.projectPath ?? '~'} [${i.scope}]: still at ${i.version}, not ${version}`);
  }

  // Cache: every file the release commit has for the plugin.
  const cache = join(home, `.claude/plugins/cache/${marketplace}/${plugin}/${version}`);
  if (!existsSync(cache)) {
    failures.push(`nothing installed at ${cache}`);
  } else {
    const prefix = `plugins/${plugin}/`;
    const inCache = new Set(list(cache));
    const missing = run('git', ['ls-tree', '-r', '--name-only', ref, prefix], root)
      .split('\n').filter(Boolean).map((f) => f.slice(prefix.length)).filter((f) => !inCache.has(f));
    if (missing.length) failures.push(`cache ${cache} lacks ${missing.length} file(s): ${missing.join(', ')}`);
    else log(`  ✔ cache holds every file of ${plugin} at ${ref}`);
  }

  // Load: a full cache can still fail to load — `update` does not install newly
  // declared `dependencies`. `--json` carries no load status, so read the text
  // form in each project, and fail when the plugin is absent from it: a changed
  // format must not pass silently.
  const field = (b, k) => b.match(new RegExp(`^\\s*${k}:\\s*(.*)$`, 'm'))?.[1]?.trim() ?? '?';
  for (const dir of [...new Set(all.map((i) => i.projectPath ?? home))]) {
    let blocks;
    try {
      blocks = run('claude', ['plugin', 'list'], dir).split(/^\s*❯\s+/m).slice(1)
        .filter((b) => b.split('\n')[0].trim() === id && field(b, 'Version') === version);
    } catch (e) {
      failures.push(`${dir}: \`claude plugin list\` failed — ${errText(e)}`);
      continue;
    }
    if (blocks.length === 0) failures.push(`${dir}: \`claude plugin list\` shows no ${id} at ${version}`);
    for (const b of blocks.filter((b) => /Status:.*fail/i.test(b))) {
      failures.push(`${dir} [${field(b, 'Scope')}]: FAILS TO LOAD — ${field(b, 'Error')} (missing \`dependencies\` are not installed by \`update\`)`);
    }
  }
  if (failures.length === 0) log(`  ✔ ${all.length} install(s) at ${version} and loading`);
  return failures;
}

// Uninstall every install of `plugin`, for a release that deleted it from the
// marketplace. Returns the failures, one line each; an empty array means no
// install and no project `enabledPlugins` entry is left.
export function removeConsumers({ marketplace, plugin, log = console.log }) {
  const id = `${plugin}@${marketplace}`;
  const failures = [];
  const all = installs(id);
  if (all.length === 0) log(`  ${id} is installed nowhere on this machine — nothing to remove`);
  for (const i of all) {
    const where = i.projectPath ?? '~';
    try {
      log(`  ${where} [${i.scope}]: ${run('claude', ['plugin', 'uninstall', id, '--scope', i.scope], i.projectPath ?? home).split('\n').pop()}`);
    } catch (e) {
      failures.push(`${where} [${i.scope}]: uninstall failed — ${errText(e)}`);
    }
  }
  for (const i of installs(id)) failures.push(`${i.projectPath ?? '~'} [${i.scope}]: still installed`);
  // Uninstall edits the scope's settings file; one that still enables the plugin
  // would ask every session there to load a plugin the marketplace no longer has.
  for (const dir of [...new Set(all.map((i) => i.projectPath).filter(Boolean))]) {
    const p = join(dir, '.claude/settings.json');
    if (existsSync(p) && id in (JSON.parse(readFileSync(p, 'utf8')).enabledPlugins ?? {})) {
      failures.push(`${p} still lists ${id} in enabledPlugins`);
    }
  }
  if (failures.length === 0 && all.length) log(`  ✔ ${id} removed from ${all.length} install(s)`);
  return failures;
}
