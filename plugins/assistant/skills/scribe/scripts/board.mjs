#!/usr/bin/env node
// asst-board — the task board behind one op vocabulary, so the flow never names a
// backend. The adapter (`.claude/assistant.md`, `board:`) picks where rows live:
//   notion  the project's TaskList under `notion_root` (writes via asst-notion)
//   file    the personal, unversioned .claude/.assistant/board.md (+ tasks/<slug>/)
//
// Usage: asst-board create  <slug> Name=<…> [Status=<…>] [Stage=<…>] ["Blocked by=<slug>[,…]"] [--body <file.md>]
//        asst-board set     <slug|page-id> Key=Val …
//        asst-board brief   <slug|page-id> <brief.md>          the approved brief, into the row body
//        asst-board decide  <slug> <decisions.md>              each fork the founder rules on, the moment they rule
//        asst-board archive <slug> <archive.md>                at close: the archive
//        asst-board trash   <slug|page-id>                     at close, after archive: the row leaves the board,
//                                                              and a Next row it was the last blocker of turns In Progress
//        asst-board show    <slug|page-id> [--body]           one row whole; --body adds its body after ---
//        asst-board list [--all]                               the live rows (In Progress · Next), or every row
//        asst-board --help                    Any op takes --dry-run: print, write nothing.
//
// `Blocked by` names only the rows this one waits for: slugs, or page ids on Notion,
// where it is the TaskList's built-in Dependencies relation. A `Next` row needs one.
// Everything else about a row goes in its body (`--body` at create, `brief` later);
// the file board keeps no property but Name · Status · Stage · Blocked by.
//
// decisions.md: `# <task name>`, then one `### <fork>` per ruling with a
// `**Feature**: <page>[, <page>]` line naming the product feature pages it governs
// (`none` when it governs none; required when the adapter's kb_pages lists product)
// and **Context** / **Decision** / **Consequence** paragraphs. notion: one Decision Log
// row per fork, Feature (multi-select) = its pages, Task = the task name; file:
// appended to <kb>/decisions/<slug>.md.
// archive.md: `# <task name>` and the five archive sections (## Overview · ## Problem ·
// ## Final Approach · ## Key Decisions · ## Deferred Items). file: copied verbatim to
// <kb>/<date>-<slug>.md; notion: one Feature Archive row.
// Exit 2 = no adapter / bad op / unknown slug / bad property; asst-notion failures pass through.
import { existsSync, readFileSync, writeFileSync, mkdirSync, copyFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const fail = (m) => { console.error(`asst-board: ${m}`); process.exit(2); };
const argv = process.argv.slice(2);
const dry = argv.includes('--dry-run'); const args = argv.filter(a => a !== '--dry-run');
const [op, ...rest] = args;
if (!op || op === '--help' || op === '-h') {
  const src = readFileSync(fileURLToPath(import.meta.url), 'utf8').split('\n');
  console.log(src.slice(1, src.findIndex((l, i) => i > 0 && !l.startsWith('//'))).join('\n').replace(/^\/\/ ?/gm, ''));
  process.exit(0);
}

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
const bare = (id) => String(id).replace(/-/g, '').toLowerCase();
const blockers = (v) => (Array.isArray(v) ? v : String(v ?? '').split(',')).map(s => s.trim()).filter(Boolean);
const FILE_PROPS = ['Name', 'Status', 'Stage', 'Blocked by'];
function checkProps(p, { creating }) {
  const bad = backend === 'file' ? Object.keys(p).filter(k => !FILE_PROPS.includes(k)) : [];
  if (bad.length) fail(`unknown property ${bad.join(', ')}: a row keeps ${FILE_PROPS.join(' · ')}; anything else goes in its body (--body at create, brief later).`);
  if (creating && p.Status === 'Next' && !blockers(p['Blocked by']).length)
    fail('a Next row waits on another row: pass "Blocked by=<slug>". A wait on anything outside the board is Deferred, with its condition in the body (--body).');
}

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
function decisions(md) { // "### fork" blocks → {Name, Feature?: [page…], Context, Decision, Consequence}; Feature [] = none
  const rows = []; let cur = null;
  for (const l of md.split('\n')) {
    const h = l.match(/^### (.+)$/); if (h) { cur = { Name: h[1].trim() }; rows.push(cur); continue; }
    const ft = l.match(/^\*\*Feature\*\*:?\s*(.*)$/);
    if (ft && cur) { const v = ft[1].trim(); cur.Feature = v === 'none' ? [] : v.split(/[,，、]/).map(x => x.trim()).filter(Boolean); cur._last = null; continue; }
    const f = l.match(/^\*\*(Context|Decision|Consequence)\*\*:?\s*(.*)$/); if (f && cur) { cur[f[1]] = f[2]; cur._last = f[1]; continue; }
    if (cur && cur._last && l.trim()) cur[cur._last] += '\n' + l;
  }
  return rows.map(({ _last, ...r }) => r);
}

// ── file backend: one markdown table, brief and archive as files.
const boardFile = join(stateDir, 'board.md');
const COLS = ['Slug', ...FILE_PROPS];
// Columns are read by their header, so a column the board doesn't keep stops here
// instead of being read as another one or dropped on the next write.
function readRows() {
  if (!existsSync(boardFile)) return [];
  const [head = [], , ...body] = readFileSync(boardFile, 'utf8').split('\n').filter(l => l.startsWith('|'))
    .map(l => l.split('|').slice(1, -1).map(c => c.trim()));
  const extra = head.filter(h => !COLS.includes(h));
  if (extra.length) fail(`${boardFile} has column ${extra.join(', ')}, which the board doesn't keep: move what it holds into each row's body (asst-board brief) or "Blocked by", then delete the column.`);
  return body.filter(c => c.length === head.length).map(c => Object.fromEntries(COLS.map(k => [k, c[head.indexOf(k)] ?? ''])));
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
    const bi = rest.indexOf('--body'); const body = bi < 0 ? null : rest[bi + 1];
    if (bi >= 0 && !(body && existsSync(body))) fail('--body needs a Markdown file that exists');
    const [slug, ...props] = bi < 0 ? rest : [...rest.slice(0, bi), ...rest.slice(bi + 2)];
    if (!slug || !props.length) fail('create <slug> Name=<…> …');
    const p = { Status: 'In Progress', Stage: 'Product Plan', ...kv(props) }; if (!p.Name) fail('create needs Name=');
    checkProps(p, { creating: true });
    if (backend === 'file') {
      const rows = readRows(); if (rows.some(r => r.Slug === slug)) fail(`row "${slug}" exists`);
      for (const b of blockers(p['Blocked by'])) if (!rows.some(r => r.Slug === b)) fail(`no row "${b}" to wait on`);
      rows.push({ Slug: slug, ...p }); writeRows(rows); console.log(`create ${slug} → ${boardFile}`);
      if (body) put(join(stateDir, 'tasks', slug, 'brief.md'), resolve(body));
      break;
    }
    if (p['Blocked by']) p['Blocked by'] = blockers(p['Blocked by']).map(pageIdOf);
    if (body) p.bodyFile = resolve(body);
    const out = notion(['create', '-'], JSON.stringify({ db: 'tasklist', rows: [p] }));
    const id = (out.match(/[0-9a-f]{32}/) ?? [])[0];
    if (id && !dry) { mkdirSync(dirname(pageFile(slug)), { recursive: true }); writeFileSync(pageFile(slug), id + '\n'); }
    break;
  }
  case 'set': {
    const [ref, ...props] = rest; if (!ref || !props.length) fail('set <slug|page-id> Key=Val …');
    const p = kv(props); checkProps(p, { creating: false });
    if (backend === 'file') {
      const rows = readRows(); const r = rows.find(x => x.Slug === ref); if (!r) fail(`no row "${ref}"`);
      for (const b of blockers(p['Blocked by'])) if (!rows.some(x => x.Slug === b)) fail(`no row "${b}" to wait on`);
      Object.assign(r, p); writeRows(rows); console.log(`set ${ref} ${props.join(' ')} → ${boardFile}`); break;
    }
    const args = props.map(x => x.startsWith('Blocked by=') ? `Blocked by=${blockers(p['Blocked by']).map(pageIdOf).join(',')}` : x);
    notion(['set', 'tasklist', pageIdOf(ref), ...args]); break;
  }
  case 'brief': {
    const [ref, file] = rest; if (!ref || !file || !existsSync(file)) fail('brief <slug|page-id> <brief.md>');
    if (backend === 'file') { put(join(stateDir, 'tasks', ref, 'brief.md'), resolve(file)); break; }
    notion(['append', pageIdOf(ref), resolve(file)]); break;
  }
  case 'decide': {
    const [slug, file] = rest; if (!slug || !file || !existsSync(file)) fail('decide <slug> <decisions.md>');
    const md = readFileSync(file, 'utf8'); const decs = decisions(md);
    if (!decs.length) fail(`${file} has no "### <fork>" block`);
    // A product page lists its decisions by Feature, so a decision without one never shows on any page.
    const unplaced = /\bproduct\b/.test(adapter.kb_pages ?? '') ? decs.filter(d => d.Feature === undefined).map(d => `"${d.Name}"`) : [];
    if (unplaced.length) fail(`decision ${unplaced.join(', ')} has no **Feature** line: under its ### heading, name the product feature pages it governs, "**Feature**: <page>[, <page>]", or "**Feature**: none".`);
    const name = (md.match(/^# (.+)$/m) ?? [, slug])[1].trim();
    if (backend === 'file') {
      if (!adapter.kb) fail('adapter board: file needs kb: <dir>');
      const dest = join(root, adapter.kb, 'decisions', `${slug}.md`); const forks = md.slice(md.search(/^### /m)).trimEnd() + '\n';
      if (dry) { console.log(`would append ${decs.length} decisions to ${dest}`); break; }
      mkdirSync(dirname(dest), { recursive: true });
      writeFileSync(dest, existsSync(dest) ? readFileSync(dest, 'utf8').trimEnd() + '\n\n' + forks : `# ${name}\n\n${forks}`); console.log(dest);
      break;
    }
    notion(['create', '-'], JSON.stringify({ db: 'decision-log', rows: decs.map(({ Name, Feature, ...d }) =>
      ({ Name, ...(Feature?.length ? { Feature } : {}), ...d, Task: name, Status: 'Active', Decided: today })) }));
    break;
  }
  case 'archive': {
    const [slug, file] = rest; if (!slug || !file || !existsSync(file)) fail('archive <slug> <archive.md>');
    const md = readFileSync(file, 'utf8');
    if (sections(md).Decisions) fail(`${file} has a "## Decisions" section: file each fork with "asst-board decide <slug> <decisions.md>" (already filed ones skip this), then delete the section.`);
    if (backend === 'file') { if (!adapter.kb) fail('adapter board: file needs kb: <dir>'); put(join(root, adapter.kb, `${today}-${slug}.md`), resolve(file)); break; }
    const s = sections(md); const name = (md.match(/^# (.+)$/m) ?? [, slug])[1].trim();
    const archiveRow = { Name: name, Status: 'Shipped', 'Shipped Date': today };
    for (const k of ['Overview', 'Problem', 'Final Approach', 'Key Decisions', 'Deferred Items']) if (s[k]) archiveRow[k] = s[k];
    notion(['create', '-'], JSON.stringify({ db: 'feature-archive', rows: [archiveRow] }));
    break;
  }
  case 'show': {
    const [ref] = rest.filter(a => a !== '--body'); const body = rest.includes('--body');
    if (!ref) fail('show <slug|page-id> [--body]');
    if (backend === 'file') {
      const r = readRows().find(x => x.Slug === ref); if (!r) fail(`no row "${ref}"`);
      console.log(JSON.stringify(r));
      const brief = join(stateDir, 'tasks', ref, 'brief.md');
      if (body) { console.log('---'); console.log(existsSync(brief) ? readFileSync(brief, 'utf8').trimEnd() : '(no body filed)'); }
      break;
    }
    notion(['get', pageIdOf(ref), ...(body ? ['--body'] : [])], undefined, { write: false }); break;
  }
  case 'list': {
    const all = rest.includes('--all');
    const live = (r) => ['In Progress', 'Next'].includes(r.Status);
    // The count leads, so a list cut short on screen still says how long it is.
    const print = (lines) => console.log([`${lines.length} rows (${all ? 'all' : 'live'})`, ...lines].join('\n'));
    // A row's `Blocked by` shows only the blockers still on the board.
    if (backend === 'file') {
      const rows = readRows(); const on = new Set(rows.map(r => r.Slug));
      print(rows.filter(r => all || live(r)).map(r => [r.Slug, r.Name, r.Status, r.Stage, blockers(r['Blocked by']).filter(b => on.has(b)).join(', ')].join(' · ')));
      break;
    }
    // One query for every row, followed to its last page: which blockers are still on the board needs them all.
    const rows = notionRows([]);
    if (dry) break;
    const byId = new Map(rows.map(r => [bare(r.id), r]));
    print(rows.filter(r => all || live(r)).map(r => [r.Name, r.Status, r.Stage,
      blockers(r['Blocked by']).map(id => byId.get(bare(id))?.Name).filter(Boolean).join(', '), r.id].map(v => v ?? '').join(' · ')));
    break;
  }
  case 'trash': {
    const [ref] = rest; if (!ref) fail('trash <slug|page-id>');
    // A Next row whose last blocker this was turns In Progress. That happens before the
    // trash, so a failed trash leaves the closed row to retry, never a Next row waiting on nothing.
    if (backend === 'file') {
      const rows = readRows(); const i = rows.findIndex(x => x.Slug === ref); if (i < 0) fail(`no row "${ref}"`);
      rows.splice(i, 1); const on = new Set(rows.map(r => r.Slug));
      for (const r of rows) {
        const was = blockers(r['Blocked by']); if (!was.includes(ref)) continue;
        r['Blocked by'] = was.filter(b => b !== ref).join(',');
        if (r.Status === 'Next' && !was.some(b => b !== ref && on.has(b))) { r.Status = 'In Progress'; console.log(`unblocked ${r.Slug} → In Progress`); }
      }
      writeRows(rows); console.log(`trash ${ref} → ${boardFile}`); break;
    }
    const id = bare(pageIdOf(ref)); const rows = notionRows([]); const on = new Set(rows.map(r => bare(r.id)));
    for (const r of rows) {
      const was = blockers(r['Blocked by']).map(bare);
      if (r.Status !== 'Next' || !was.includes(id) || was.some(b => b !== id && on.has(b))) continue;
      notion(['set', 'tasklist', bare(r.id), 'Status=In Progress']); console.log(`unblocked ${r.Name} (${r.id}) → In Progress`);
    }
    notion(['trash', id]); break;
  }
  default: fail(`unknown op "${op}" (create · set · brief · decide · archive · trash · show · list)`);
}
