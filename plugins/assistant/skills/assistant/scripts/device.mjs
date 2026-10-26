#!/usr/bin/env node
// asst-device — the on-device leg: does every scenario the brief numbers have a
// test, is every test wired, and does the suite pass on a real phone of each
// platform the project ships. Files the result as the task's verify-device
// report, so `asst-pr ready` can require it.
//
// Usage: asst-device <task-slug> <worktree> [--brief <file>]
//   The brief's scenario ids are the lines `- S<n> …`, `- F<n> …`, `- B<n> …`
//   (references/brief.md); without --brief it is read from the task's board row
//   (`asst-board show <slug> --body`). A test covers an id when its name starts
//   with `[<id>]`; one still marked `until wired` covers nothing.
//
// Adapter (references/project.md):
//   device_test: <command>    run in the worktree once per platform, `{device}`
//                             replaced by the phone's id from `flutter devices`
//   devices:     android ios  the platforms that must pass (default: both)
//   features:    <path>       the project's feature list, counted, never blocking
//
// A platform with no physical device connected, or one whose phone another run
// holds, is `not run` — never passed. Exit: 0 passed · 1 not passed · 2 usage.

import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const usage = () => { console.error('Usage: asst-device <task-slug> <worktree> [--brief <file>]'); process.exit(2); };
const [slug, wtArg, flag, briefArg] = args;
if (!slug || !wtArg || (flag && (flag !== '--brief' || !briefArg)) || args.length > 4) usage();
const wt = resolve(wtArg);
if (!existsSync(wt)) { console.error(`asst-device: no worktree at ${wt}`); process.exit(2); }

const root = execFileSync('bash', [join(here, 'root.sh')], { cwd: wt, encoding: 'utf8' }).trim();
const adapterPath = join(root, '.claude/assistant.md');
const adapter = existsSync(adapterPath) ? readFileSync(adapterPath, 'utf8') : '';
const field = (name) => adapter.match(new RegExp(`^${name}:[ \\t]*([^#\\n]*[^#\\s])`, 'm'))?.[1] ?? '';
const command = field('device_test');
if (!command || command === 'none') {
  console.error(`asst-device: the adapter has no device_test: command (${adapterPath})`);
  process.exit(2);
}
const platforms = (field('devices') || 'android ios').split(/\s+/);

// ── scenarios ──
let brief;
if (briefArg) {
  if (!existsSync(briefArg)) { console.error(`asst-device: no brief at ${briefArg}`); process.exit(2); }
  brief = readFileSync(briefArg, 'utf8');
} else {
  const r = spawnSync('asst-board', ['show', slug, '--body'], { cwd: wt, encoding: 'utf8' });
  if (r.status !== 0) { console.error(`asst-device: couldn't read the brief from the board (asst-board show ${slug} --body):\n${r.stderr}`); process.exit(2); }
  brief = r.stdout;
}
const ids = [...new Set([...brief.matchAll(/^\s*- ([SFB]\d+)\b/gm)].map((m) => m[1]))];
if (!ids.length) {
  console.error('asst-device: the brief numbers no scenario (`- S1 …`, `- F1 …`, `- B1 …` — references/brief.md)');
  process.exit(2);
}
const grep = (pattern) => {
  const r = spawnSync('git', ['-C', wt, 'grep', '--untracked', '-nE', pattern, '--', '.'], { encoding: 'utf8' });
  return r.stdout.split('\n').filter(Boolean);
};
const unwired = grep('until wired');
const unwiredFiles = new Set(unwired.map((l) => l.split(':')[0]));
// A test runs from its name to the next test's name in the same file; one with
// an `until wired` marker in that range covers nothing.
const at = (l) => { const [file, n] = l.split(':'); return { file, n: Number(n), text: l }; };
const tags = grep('\\[[SFB][0-9]+\\]').map(at);
const marks = unwired.map(at);
const covered = new Set();
for (const t of tags) {
  const end = Math.min(...tags.filter((o) => o.file === t.file && o.n > t.n).map((o) => o.n), Infinity);
  if (marks.some((m) => m.file === t.file && m.n >= t.n && m.n < end)) continue;
  for (const m of t.text.matchAll(/\[([SFB]\d+)\]/g)) covered.add(m[1]);
}
const missing = ids.filter((id) => !covered.has(id));

// ── features ──
let featureLine = 'features: no list (adapter features: unset)';
const fpath = field('features');
if (fpath && fpath !== 'none') {
  const fp = join(wt, fpath);
  if (existsSync(fp)) {
    const rows = readFileSync(fp, 'utf8').split('\n').filter((l) => /^- .+ · /.test(l));
    const gaps = rows.filter((l) => / · none\b/.test(l));
    featureLine = `features: ${rows.length} · without an on-device test: ${gaps.length}`;
  } else {
    featureLine = `features: ${fpath} not found in the worktree`;
  }
}

// ── devices ──
let found = [];
const fl = spawnSync('flutter', ['devices', '--machine'], { encoding: 'utf8' });
if (fl.status === 0) {
  try { found = JSON.parse(fl.stdout.slice(fl.stdout.indexOf('['))); } catch { found = []; }
}
const platformOf = (d) => (String(d.targetPlatform).startsWith('android') ? 'android' : String(d.targetPlatform).startsWith('ios') ? 'ios' : '');
const logDir = join(root, '.claude/.assistant/tasks', slug);
mkdirSync(logDir, { recursive: true });

const results = {};
for (const p of platforms) {
  const phone = found.find((d) => !d.emulator && platformOf(d) === p);
  if (fl.status !== 0) { results[p] = `not run — \`flutter devices\` failed`; continue; }
  if (!phone) { results[p] = `not run — no ${p} phone connected`; continue; }
  const lock = join(tmpdir(), `asst-device-${String(phone.id).replace(/[^\w.-]/g, '_')}.lock`);
  try { mkdirSync(lock); } catch { results[p] = `not run — ${phone.name} is busy with another run (${lock})`; continue; }
  const log = join(logDir, `device-${p}.log`);
  const started = Date.now();
  try {
    const r = spawnSync('bash', ['-c', command.replaceAll('{device}', phone.id)], { cwd: wt, encoding: 'utf8', maxBuffer: 1 << 28 });
    writeFileSync(log, (r.stdout ?? '') + (r.stderr ?? ''));
    const secs = Math.round((Date.now() - started) / 1000);
    results[p] = `${r.status === 0 ? 'passed' : `failed (exit ${r.status})`} on ${phone.name} in ${secs}s · log ${log}`;
  } finally {
    rmSync(lock, { recursive: true, force: true });
  }
}

const reasons = [
  ...platforms.filter((p) => !results[p].startsWith('passed')).map((p) => `${p} ${results[p].split(' ')[0] === 'not' ? 'not run' : 'failed'}`),
  ...(missing.length ? [`${missing.length} scenario(s) without a test`] : []),
  ...(unwired.length ? [`${unwired.length} test(s) still until wired`] : []),
];
const passed = reasons.length === 0;
const report = [
  passed ? 'device: passed' : `device: not passed — ${reasons.join(', ')}`,
  ...platforms.map((p) => `${p}: ${results[p]}`),
  `scenarios: ${ids.length - missing.length}/${ids.length} have a test${missing.length ? ` · missing: ${missing.join(' ')}` : ''}`,
  `unwired: ${unwired.length ? [...unwiredFiles].join(' ') : 'none'}`,
  featureLine,
].join('\n') + '\n';

process.stdout.write(report);
const put = spawnSync('bash', [join(here, 'report.sh'), 'put', slug, 'verify-device', '--worktree', wt], { cwd: wt, input: report, encoding: 'utf8' });
process.stdout.write(put.stdout);
if (put.status !== 0) { process.stderr.write(put.stderr); process.exit(2); }
process.exit(passed ? 0 : 1);
