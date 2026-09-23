#!/usr/bin/env node
// asst-board — the task board behind one op vocabulary, so the flow never names a
// backend. The adapter (`.claude/assistant.md`, `board:`) picks where rows live:
//   notion  the project's TaskList under `notion_root` (writes via asst-notion)
//   file    the personal, unversioned .claude/.assistant/board.md (+ tasks/<slug>/)
//
// Usage: asst-board create  <slug> Name=<…> [Status=<…>] [Stage=<…>] [Trigger=<…>]
//        asst-board set     <slug|page-id> Key=Val …
//        asst-board brief   <slug|page-id> <brief.md>          the approved brief, into the row body
//        asst-board archive <slug> <archive.md>                at close: the archive + its decisions
//        asst-board list [--all]                               the live rows (In Progress · Next), or every row
//        asst-board --help                    Any op takes --dry-run: print, write nothing.
//
// archive.md: the five archive sections (## Overview · ## Problem · ## Final Approach
// · ## Key Decisions · ## Deferred Items) then `## Decisions`, one `### <fork>` each
// with **Context** / **Decision** / **Consequence** paragraphs. file: copied verbatim
// to <kb>/<date>-<slug>.md; notion: one feature-archive row + one decision-log row
// per fork.
// Exit 2 = no adapter / bad op / unknown slug; asst-notion failures pass through.
import { existsSync, readFileSync, writeFileSync, mkdirSync, copyFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const fail = (m) => { console.error(`asst-board: ${m}`); process.exit(2); };
const argv = process.argv.slice(2);
const dry = argv.includes('--dry-run'); const args = argv.filter(a => a !== '--dry-run');
const [op, ...rest] = args;
if (!op || op === '--help' || op === '-h') { console.log(readFileSync(fileURLToPath(import.meta.url), 'utf8').split('\n').slice(1, 20).join('\n').replace(/^\/\/ ?/gm, '')); process.exit(0); }

const root = spawnSync('bash', [join(here, '../../assistant/scripts/root.sh')], { encoding: 'utf8' }).stdout.trim();
const adapterPath = join(root, '.claude/assistant.md');
if (!existsSync(adapterPath)) fail(`no adapter at ${adapterPath} — the assistant writes one (references/project.md) before any board op.`);
const adapter = Object.fromEntries(readFileSync(adapterPath, 'utf8').split('\n')
  .map(l => l.match(/^\s*([a-z_]+):\s*([^#]*?)\s*(#.*)?$/)).filter(Boolean).map(m => [m[1], m[2]]));
const backend = adapter.board;
if (!['notion', 'file'].includes(backend)) fail(`adapter board: must be notion | file (got "${backend ?? ''}")`);
const stateDir = join(root, '.claude/.assistant');
const today = new Date().toISOString().slice(0, 10);
const kv = (xs) => Object.fromEntries(xs.map(x => { const i = x.indexOf('='); if (i < 1) fail(`expected Key=Val, got "${x}"`); return [x.slice(0, i), x.slice(i + 1)]; }));
const isPageId = (s) => /^[0-9a-f]{32}$|^[0-9a-f-]{36}$/i.test(s);

// ── notion backend: every write is an asst-notion command; --dry-run prints it.
function notion(cmdArgs, stdin, { write = true } = {}) {
  const line = ['asst-notion', ...cmdArgs, '--root', adapter.notion_root, ...(write ? ['--commit'] : [])];
  if (!adapter.notion_root) fail('adapter board: notion needs notion_root:');
  if (dry) { console.log(line.join(' ') + (stdin ? `\n${stdin}` : '')); return ''; }
  const r = spawnSync(line[0], line.slice(1), { encoding: 'utf8', input: stdin });
  if (r.error) fail(`asst-notion: ${r.error.message}`);
  process.stdout.write(r.stdout); process.stderr.write(r.stderr);
  if (r.status !== 0) process.exit(r.status);
  return r.stdout;
}
function notionRows(pairs) {
  if (!adapter.notion_root) fail('adapter board: notion needs notion_root:');
  const line = ['asst-notion', 'query', 'tasklist', ...pairs, '--root', adapter.notion_root];
  if (dry) { console.log(line.join(' ')); return []; }
  const r = spawnSync(line[0], line.slice(1), { encoding: 'utf8' });
  if (r.error) fail(`asst-notion: ${r.error.message}`);
  if (r.status !== 0) { process.stderr.write(r.stderr); process.exit(r.status); }
  const [head, ...lines] = r.stdout.trim().split('\n');
  const rows = lines.map(l => JSON.parse(l));
  if (rows.length !== JSON.parse(head).count) fail(`asst-notion query said ${JSON.parse(head).count} rows, sent ${rows.length}`);
  return rows;
}
const pageFile = (slug) => join(stateDir, 'tasks', slug, 'page');
function pageIdOf(ref) {
  if (isPageId(ref)) return ref;
  const f = pageFile(ref);
  if (existsSync(f)) return readFileSync(f, 'utf8').trim();
  fail(`no page id recorded for "${ref}" (${f}) — pass the page id instead.`);
}
function sections(md) { // "## H" → body text, in order
  const out = {}; let h = null;
  for (const l of md.split('\n')) { const m = l.match(/^## (.+)$/); if (m) { h = m[1].trim(); out[h] = ''; } else if (h) out[h] += l + '\n'; }
  for (const k in out) out[k] = out[k].trim(); return out;
}
function decisions(md) { // "### fork" blocks under ## Decisions → {Name, Context, Decision, Consequence}
  const body = sections(md).Decisions ?? ''; const rows = []; let cur = null;
  for (const l of body.split('\n')) {
    const h = l.match(/^### (.+)$/); if (h) { cur = { Name: h[1].trim() }; rows.push(cur); continue; }
    const f = l.match(/^\*\*(Context|Decision|Consequence)\*\*:?\s*(.*)$/); if (f && cur) { cur[f[1]] = f[2]; cur._last = f[1]; continue; }
    if (cur && cur._last && l.trim()) cur[cur._last] += '\n' + l;
  }
  return rows.map(({ _last, ...r }) => r);
}

// ── file backend: one markdown table, brief and archive as files.
const boardFile = join(stateDir, 'board.md');
const COLS = ['Slug', 'Name', 'Status', 'Stage', 'Trigger'];
function readRows() {
  if (!existsSync(boardFile)) return [];
  return readFileSync(boardFile, 'utf8').split('\n').filter(l => l.startsWith('|')).slice(2)
    .map(l => l.split('|').slice(1, -1).map(c => c.trim())).filter(c => c.length === COLS.length)
    .map(c => Object.fromEntries(COLS.map((k, i) => [k, c[i]])));
}
function writeRows(rows) {
  if (dry) { console.log(rows.map(r => COLS.map(k => r[k] ?? '').join(' | ')).join('\n')); return; }
  mkdirSync(stateDir, { recursive: true });
  const line = (r) => `| ${COLS.map(k => r[k] ?? '').join(' | ')} |`;
  writeFileSync(boardFile, [`| ${COLS.join(' | ')} |`, `|${COLS.map(() => '---').join('|')}|`, ...rows.map(line), ''].join('\n'));
}
function put(dest, src) {
  if (dry) { console.log(`would write ${dest}`); return; }
  mkdirSync(dirname(dest), { recursive: true }); copyFileSync(src, dest); console.log(dest);
}

switch (op) {
  case 'create': {
    const [slug, ...props] = rest; if (!slug || !props.length) fail('create <slug> Name=<…> …');
    const p = { Status: 'In Progress', Stage: 'Product Plan', ...kv(props) }; if (!p.Name) fail('create needs Name=');
    if (backend === 'file') { const rows = readRows(); if (rows.some(r => r.Slug === slug)) fail(`row "${slug}" exists`); rows.push({ Slug: slug, ...p }); writeRows(rows); console.log(`create ${slug} → ${boardFile}`); break; }
    const out = notion(['create', '-'], JSON.stringify({ db: 'tasklist', rows: [p] }));
    const id = (out.match(/[0-9a-f]{32}/) ?? [])[0];
    if (id && !dry) { mkdirSync(dirname(pageFile(slug)), { recursive: true }); writeFileSync(pageFile(slug), id + '\n'); }
    break;
  }
  case 'set': {
    const [ref, ...props] = rest; if (!ref || !props.length) fail('set <slug|page-id> Key=Val …');
    const p = kv(props);
    if (backend === 'file') { const rows = readRows(); const r = rows.find(x => x.Slug === ref); if (!r) fail(`no row "${ref}"`); Object.assign(r, p); writeRows(rows); console.log(`set ${ref} ${props.join(' ')} → ${boardFile}`); break; }
    notion(['set', 'tasklist', pageIdOf(ref), ...props]); break;
  }
  case 'brief': {
    const [ref, file] = rest; if (!ref || !file || !existsSync(file)) fail('brief <slug|page-id> <brief.md>');
    if (backend === 'file') { put(join(stateDir, 'tasks', ref, 'brief.md'), resolve(file)); break; }
    notion(['append', pageIdOf(ref), resolve(file)]); break;
  }
  case 'archive': {
    const [slug, file] = rest; if (!slug || !file || !existsSync(file)) fail('archive <slug> <archive.md>');
    const md = readFileSync(file, 'utf8');
    if (backend === 'file') { if (!adapter.kb) fail('adapter board: file needs kb: <dir>'); put(join(root, adapter.kb, `${today}-${slug}.md`), resolve(file)); break; }
    const s = sections(md); const name = (md.match(/^# (.+)$/m) ?? [, slug])[1].trim();
    const archiveRow = { Name: name, Status: 'Shipped', 'Shipped Date': today };
    for (const k of ['Overview', 'Problem', 'Final Approach', 'Key Decisions', 'Deferred Items']) if (s[k]) archiveRow[k] = s[k];
    notion(['create', '-'], JSON.stringify({ db: 'feature-archive', rows: [archiveRow] }));
    const decs = decisions(md).map(d => ({ ...d, Status: 'Active', Feature: name, Decided: today }));
    if (decs.length) notion(['create', '-'], JSON.stringify({ db: 'decision-log', rows: decs }));
    break;
  }
  case 'list': {
    const all = rest.includes('--all');
    const live = (r) => ['In Progress', 'Next'].includes(r.Status);
    // The count leads, so a list cut short on screen still says how long it is.
    const print = (lines) => console.log([`${lines.length} rows (${all ? 'all' : 'live'})`, ...lines].join('\n'));
    if (backend === 'file') { print(readRows().filter(r => all || live(r)).map(r => COLS.map(k => r[k]).join(' · '))); break; }
    // One query per status, each followed to its last page by asst-notion query.
    const rows = (all ? [[]] : [['Status=In Progress'], ['Status=Next']]).flatMap(notionRows);
    if (!dry) print(rows.map(r => [r.Name, r.Status, r.Stage, r.Trigger, r.id].map(v => v ?? '').join(' · ')));
    break;
  }
  default: fail(`unknown op "${op}" (create · set · brief · archive · list)`);
}
