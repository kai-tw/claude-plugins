#!/usr/bin/env node
// asst-strings — what the founder did with each string at ②, kept as examples to
// draft from and as a rate that says whether drafts are getting closer.
//
// Rules can't hold everything a native speaker hears, so drafting starts from the
// founder's own before → after pairs instead, and the acceptance rate is the
// check that it works.
//
// Usage:
//   asst-strings record <task-slug>     stdin: one line per string decided at ②
//       <key> · <locale> · <role> · <outcome> · <draft> → <final>
//       outcome: accepted (final = draft; `→ <final>` may be left out) · picked
//       (another of the options) · rewritten (the founder's own wording) ·
//       dropped (final is `-`)
//   asst-strings examples <role|all> <locale> [--limit <n>]
//       the founder's changes for that role and locale, newest first: this
//       project's log, then the cross-project examples ui-text-pack ships
//   asst-strings rate
//       per task, oldest first, how many strings were accepted as drafted
//
// Roles: button · title · label · caption · toast · dialog · empty · error · other.
// The log is <root>/.claude/.assistant/strings.tsv. Exit: 0 ok · 1 a bad line,
// nothing recorded · 2 usage.

import { execFileSync } from 'node:child_process';
import { appendFileSync, existsSync, mkdirSync, readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROLES = ['button', 'title', 'label', 'caption', 'toast', 'dialog', 'empty', 'error', 'other'];
const OUTCOMES = ['accepted', 'picked', 'rewritten', 'dropped'];
const here = dirname(fileURLToPath(import.meta.url));
const seeds = join(here, '../../ui-text-pack/examples');

const usage = () => {
  console.error('Usage: asst-strings record <task-slug> < lines\n'
    + '       asst-strings examples <role|all> <locale> [--limit <n>]\n'
    + '       asst-strings rate');
  process.exit(2);
};

const root = () => execFileSync('bash', [join(here, 'root.sh')], { encoding: 'utf8' }).trim();
const logPath = () => join(root(), '.claude/.assistant/strings.tsv');
const clean = (s) => s.replace(/[\t\r\n]+/g, ' ').trim();
const sameLocale = (a, b) => a.toLowerCase().replace(/_/g, '-') === b.toLowerCase().replace(/_/g, '-');

// Log columns: date · slug · key · locale · role · outcome · draft · final
function readLog() {
  const p = logPath();
  if (!existsSync(p)) return [];
  return readFileSync(p, 'utf8').split('\n').filter(Boolean).map((l) => {
    const [date, slug, key, locale, role, outcome, draft, final] = l.split('\t');
    return { date, slug, key, locale, role, outcome, draft, final };
  });
}

// Seed columns: locale · role · where it renders · draft · final; `#` lines are comments.
function readSeeds() {
  if (!existsSync(seeds)) return [];
  return readdirSync(seeds).filter((f) => f.endsWith('.tsv')).flatMap((f) =>
    readFileSync(join(seeds, f), 'utf8').split('\n')
      .filter((l) => l.trim() && !l.startsWith('#'))
      .map((l) => {
        const [locale, role, where, draft, final] = l.split('\t');
        return { locale, role, where, draft, final };
      }));
}

const [cmd, ...args] = process.argv.slice(2);

if (cmd === 'record') {
  const [slug] = args;
  if (!slug || args.length > 1) usage();
  const lines = readFileSync(0, 'utf8').split('\n').filter((l) => l.trim());
  if (!lines.length) { console.error('asst-strings: nothing on stdin'); process.exit(1); }
  const date = new Date().toISOString().slice(0, 10);
  const rows = []; const bad = [];
  for (const line of lines) {
    const parts = line.split(' · ');
    if (parts.length < 5) { bad.push(`${line}\n    expected <key> · <locale> · <role> · <outcome> · <draft> → <final>`); continue; }
    const [key, locale, role, outcome] = parts.slice(0, 4).map(clean);
    const rest = parts.slice(4).join(' · ');
    const at = rest.indexOf(' → ');
    const draft = clean(at < 0 ? rest : rest.slice(0, at));
    let final = at < 0 ? '' : clean(rest.slice(at + 3));
    const why = [];
    if (!ROLES.includes(role)) why.push(`role "${role}" is not one of ${ROLES.join(' ')}`);
    if (!OUTCOMES.includes(outcome)) why.push(`outcome "${outcome}" is not one of ${OUTCOMES.join(' ')}`);
    if (outcome === 'accepted') {
      if (final && final !== draft) why.push('accepted, but the final value differs from the draft — say picked or rewritten');
      final = draft;
    } else if (outcome === 'dropped') {
      if (final && final !== '-') why.push('dropped takes `→ -`');
      final = '-';
    } else if (!final || final === draft) {
      why.push(`${outcome} needs a final value that differs from the draft`);
    }
    if (!draft) why.push('no draft');
    if (why.length) bad.push(`${line}\n    ${why.join('; ')}`);
    else rows.push([date, slug, key, locale, role, outcome, draft, final].join('\t'));
  }
  if (bad.length) {
    console.error(`asst-strings: nothing recorded — fix these lines:\n  ${bad.join('\n  ')}`);
    process.exit(1);
  }
  const p = logPath();
  mkdirSync(dirname(p), { recursive: true });
  appendFileSync(p, rows.map((r) => r + '\n').join(''));
  console.log(`recorded ${rows.length} string(s) for ${slug} → ${p}`);
} else if (cmd === 'examples') {
  const [role, locale, flag, n] = args;
  if (!role || !locale || (flag && flag !== '--limit') || (flag && !/^\d+$/.test(n ?? ''))) usage();
  if (role !== 'all' && !ROLES.includes(role)) { console.error(`asst-strings: role "${role}" is not one of all ${ROLES.join(' ')}`); process.exit(2); }
  const limit = flag ? Number(n) : 12;
  const fits = (e) => sameLocale(e.locale, locale) && (role === 'all' || e.role === role);
  const own = readLog().filter((e) => e.outcome !== 'accepted' && fits(e)).reverse()
    .map((e) => ({ head: `${e.role} · ${e.locale} · ${e.key} · ${e.outcome} (${e.slug}, ${e.date})`, ...e }));
  const shipped = readSeeds().filter(fits)
    .map((e) => ({ head: `${e.role} · ${e.locale} · ${e.where}`, ...e }));
  const all = [...own, ...shipped].slice(0, limit);
  if (!all.length) { console.log(`no examples for ${role} · ${locale} yet`); process.exit(0); }
  for (const e of all) {
    console.log(`[${e.head}]\n  draft: ${e.draft}\n  final: ${e.final === '-' ? '(dropped)' : e.final}`);
  }
} else if (cmd === 'rate') {
  if (args.length) usage();
  const log = readLog();
  if (!log.length) { console.log('no strings recorded yet'); process.exit(0); }
  const tasks = new Map();
  for (const e of log) {
    const t = tasks.get(e.slug) ?? { date: e.date, n: 0, accepted: 0, picked: 0, rewritten: 0, dropped: 0 };
    t.n++; t[e.outcome] = (t[e.outcome] ?? 0) + 1;
    tasks.set(e.slug, t);
  }
  const line = (name, t) => `${name}  ${t.accepted}/${t.n} accepted as drafted (${Math.round((100 * t.accepted) / t.n)}%)`
    + ` · picked ${t.picked} · rewritten ${t.rewritten} · dropped ${t.dropped}`;
  const total = { n: 0, accepted: 0, picked: 0, rewritten: 0, dropped: 0 };
  for (const [slug, t] of tasks) {
    console.log(line(`${t.date} ${slug}`, t));
    for (const k of Object.keys(total)) total[k] += t[k];
  }
  console.log(line('all', total));
} else {
  usage();
}
