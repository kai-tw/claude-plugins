#!/usr/bin/env node
// flow.mjs — block/flow contract inspection and mechanical validation.
//
// WHY THIS EXISTS
//   The launcher is a router, and the procedures live in blocks it reads on
//   demand. That only stays true if something checks the seams: a block whose
//   contract nobody validates drifts, and it drifts SILENTLY because each file
//   reads plausibly on its own. This is that check — the reason the split can
//   be made at all, which is why it lands before any content moves.
//
// PROVENANCE
//   A faithful port of my-workflow's `scripts/flow/flow.py` (user-scope,
//   2026-09-09 snapshot) — same frontmatter contract, same F1/F2/F3 checks,
//   same exit codes. It is a SECOND COPY on purpose: that skill is user-scope
//   and personal, this is a versioned plugin shipped to consumer repos, and a
//   plugin cannot depend on a user-scope script. Same convention the assets
//   scripts there already use — the origin stays the origin; when it changes,
//   this is re-ported deliberately, not automatically.
//
//   Rewritten in Node rather than ported as Python because plan-cycle already
//   hard-depends on node (`plan_lint.sh` shells to `notion_payload.mjs`) and
//   depends on no Python at all. A second runtime for 300 lines is a dependency
//   nobody asked for.
//
// THE CONTRACT  (blocks/CONVENTIONS.md is the prose spec)
//   blocks/<id>.md   id · kind(native|skill) · summary · consumes · produces ·
//                    stop(true|false) [· skill (required when kind=skill)]
//                    [· scripts (paths relative to the plugin root)]
//   flows/<id>.md    id · summary · inputs · nodes("nodeId: blockId") ·
//                    edges("a -> b")
//
// CHECKS
//   F1 block   required fields · id == filename · kind enum · kind=skill has
//              `skill` · stop enum · consumes/produces are slugs · every
//              declared script exists
//   F2 flow    required fields · id == filename · node format and uniqueness ·
//              node references a real block · edge format · no self-loop ·
//              endpoints exist · the graph is a DAG
//   F3 wiring  every node's `consumes` is satisfied by flow `inputs` ∪ the
//              `produces` of its ancestors. This is the one that catches a
//              re-wiring that looks fine and starves a node.
//   warn       orphan node (no edges, in a multi-node flow)
//
// USAGE  plan-flow list | show --flow <id> | lint [--json]
// EXIT   0 ok · 1 at least one FAIL · 2 bad usage

import { readdirSync, readFileSync, statSync, existsSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const PLUGIN_ROOT = resolve(HERE, '../../..');          // …/plan-cycle
const SKILL_ROOT = resolve(HERE, '..');                 // …/skills/plan
const BLOCKS_DIR = join(SKILL_ROOT, 'blocks');
const FLOWS_DIR = join(SKILL_ROOT, 'flows');

const BLOCK_REQUIRED = ['id', 'kind', 'summary', 'consumes', 'produces', 'stop'];
const FLOW_REQUIRED = ['id', 'summary', 'inputs', 'nodes', 'edges'];
const KIND_ENUM = new Set(['native', 'skill']);
const STOP_ENUM = new Set(['true', 'false']);
const SLUG = /^[a-z0-9-]+$/;
const NODE = /^([a-z0-9-]+)\s*[:：]\s*([a-z0-9-]+)$/;
const EDGE = /^([a-z0-9-]+)\s*->\s*([a-z0-9-]+)$/;

// --- frontmatter --------------------------------------------------------------
// Only the shapes this contract uses: `key: scalar` and `key:` followed by
// `  - item` lines. Anything else throws rather than being half-read — a
// frontmatter parser that guesses is how a typo becomes a passing lint.
function parseFrontmatter(text, where) {
  if (!text.startsWith('---\n')) throw new Error('no frontmatter block');
  const end = text.indexOf('\n---', 3);
  if (end === -1) throw new Error('frontmatter block is not closed');
  const lines = text.slice(4, end).split('\n');
  const out = {};
  let key = null;
  for (const raw of lines) {
    if (!raw.trim() || raw.trimStart().startsWith('#')) continue;
    const item = raw.match(/^\s+-\s+(.*)$/);
    if (item) {
      if (!key) throw new Error(`list item with no key: ${raw.trim()}`);
      if (!Array.isArray(out[key])) out[key] = [];
      out[key].push(unquote(item[1].trim()));
      continue;
    }
    const kv = raw.match(/^([A-Za-z_][A-Za-z0-9_-]*):\s*(.*)$/);
    if (!kv) throw new Error(`unparsable line: ${raw.trim()}`);
    key = kv[1];
    const val = kv[2].trim();
    out[key] = val === '' ? [] : unquote(val);
  }
  if (!Object.keys(out).length) throw new Error(`empty frontmatter (${where})`);
  return out;
}
const unquote = (s) =>
  (s.length > 1 && ((s[0] === '"' && s.at(-1) === '"') || (s[0] === "'" && s.at(-1) === "'")))
    ? s.slice(1, -1) : s;

const asList = (v) => (Array.isArray(v) ? v : v === undefined || v === '' ? [] : [v]);

// Docs that live beside the blocks they document (the repo's `CONVENTIONS.md`
// convention) are skipped BY NAME, not by pattern. A pattern skip would also
// swallow a typo'd block filename — `Plan-Gate.md` would simply vanish from the
// listing and its flow node would fail with "block does not exist", pointing at
// the wrong file. Anything else non-slug is a hard fail so it announces itself.
const NOT_A_BLOCK = new Set(['CONVENTIONS.md', 'README.md']);

function* iterMd(dir, fails) {
  if (!existsSync(dir) || !statSync(dir).isDirectory()) return;
  for (const fn of readdirSync(dir).sort()) {
    if (!fn.endsWith('.md') || !statSync(join(dir, fn)).isFile()) continue;
    if (NOT_A_BLOCK.has(fn)) continue;
    const slug = fn.slice(0, -3);
    if (!SLUG.test(slug)) {
      fails.push([rel(join(dir, fn)), `filename is not a slug, so it can never be a valid id: ${JSON.stringify(slug)}`]);
      continue;
    }
    yield [slug, join(dir, fn)];
  }
}
const rel = (p) => p.replace(`${PLUGIN_ROOT}/`, '');

// --- F1: blocks ---------------------------------------------------------------
function loadBlocks(fails) {
  const blocks = {};
  for (const [slug, path] of iterMd(BLOCKS_DIR, fails)) {
    let fm;
    try {
      fm = parseFrontmatter(readFileSync(path, 'utf8'), rel(path));
    } catch (e) {
      fails.push([rel(path), `frontmatter unreadable: ${e.message}`]);
      continue;
    }
    const missing = BLOCK_REQUIRED.filter((f) => !(f in fm));
    if (missing.length) fails.push([rel(path), `block is missing required field(s): ${missing.join(', ')}`]);
    if (fm.id !== slug) fails.push([rel(path), `id does not match the filename: id=${JSON.stringify(fm.id)} file=${JSON.stringify(slug)}`]);
    if ('kind' in fm && !KIND_ENUM.has(fm.kind)) fails.push([rel(path), `kind must be native|skill: ${JSON.stringify(fm.kind)}`]);
    if (fm.kind === 'skill' && !fm.skill) fails.push([rel(path), 'kind=skill must declare `skill:` (what it delegates to)']);
    if ('stop' in fm && !STOP_ENUM.has(String(fm.stop))) fails.push([rel(path), `stop must be true|false: ${JSON.stringify(fm.stop)}`]);
    for (const field of ['consumes', 'produces']) {
      for (const a of asList(fm[field])) {
        if (typeof a !== 'string' || !SLUG.test(a)) fails.push([rel(path), `${field} holds a non-slug artifact: ${JSON.stringify(a)}`]);
      }
    }
    for (const s of asList(fm.scripts)) {
      if (!existsSync(join(PLUGIN_ROOT, String(s)))) {
        fails.push([rel(path), `declared script does not exist (relative to the plugin root): ${JSON.stringify(s)}`]);
      }
    }
    blocks[slug] = {
      id: slug, path, kind: fm.kind, skill: fm.skill, summary: fm.summary || '',
      consumes: asList(fm.consumes), produces: asList(fm.produces),
      stop: String(fm.stop) === 'true',
    };
  }
  return blocks;
}

// --- F2: DAG ------------------------------------------------------------------
function topo(nodes, edges, fails, where) {
  const ids = Object.keys(nodes);
  const indeg = Object.fromEntries(ids.map((n) => [n, 0]));
  const out = Object.fromEntries(ids.map((n) => [n, []]));
  for (const [a, b] of edges) { out[a].push(b); indeg[b] += 1; }
  const queue = ids.filter((n) => indeg[n] === 0).sort();
  const order = [];
  while (queue.length) {
    const n = queue.shift();
    order.push(n);
    for (const m of out[n].sort()) if (--indeg[m] === 0) queue.push(m);
    queue.sort();
  }
  if (order.length !== ids.length) {
    fails.push([where, 'edges form a cycle — a pipeline must be a DAG']);
    return null;
  }
  return order;
}

// --- F2/F3: flows -------------------------------------------------------------
function loadFlows(blocks, fails, warns) {
  const flows = {};
  for (const [slug, path] of iterMd(FLOWS_DIR, fails)) {
    let fm;
    try {
      fm = parseFrontmatter(readFileSync(path, 'utf8'), rel(path));
    } catch (e) {
      fails.push([rel(path), `frontmatter unreadable: ${e.message}`]);
      continue;
    }
    const missing = FLOW_REQUIRED.filter((f) => !(f in fm));
    if (missing.length) fails.push([rel(path), `flow is missing required field(s): ${missing.join(', ')}`]);
    if (fm.id !== slug) fails.push([rel(path), `id does not match the filename: id=${JSON.stringify(fm.id)} file=${JSON.stringify(slug)}`]);

    const inputs = new Set();
    for (const a of asList(fm.inputs)) {
      if (typeof a !== 'string' || !SLUG.test(a)) fails.push([rel(path), `inputs holds a non-slug artifact: ${JSON.stringify(a)}`]);
      else inputs.add(a);
    }
    const nodes = {};
    for (const raw of asList(fm.nodes)) {
      const m = String(raw).trim().match(NODE);
      if (!m) { fails.push([rel(path), `node must be "nodeId: blockId": ${JSON.stringify(raw)}`]); continue; }
      const [, nid, bid] = m;
      if (nid in nodes) { fails.push([rel(path), `duplicate node id: ${JSON.stringify(nid)}`]); continue; }
      if (!(bid in blocks)) { fails.push([rel(path), `node ${JSON.stringify(nid)} references a block that does not exist: ${JSON.stringify(bid)}`]); continue; }
      nodes[nid] = bid;
    }
    const edges = [];
    for (const raw of asList(fm.edges)) {
      const m = String(raw).trim().match(EDGE);
      if (!m) { fails.push([rel(path), `edge must be "a -> b": ${JSON.stringify(raw)}`]); continue; }
      const [, a, b] = m;
      if (a === b) { fails.push([rel(path), `edge cannot be a self-loop: ${JSON.stringify(raw)}`]); continue; }
      const bad = [a, b].filter((n) => !(n in nodes));
      if (bad.length) { fails.push([rel(path), `edge endpoint is not a node: ${JSON.stringify(raw)}`]); continue; }
      edges.push([a, b]);
    }
    const order = Object.keys(nodes).length ? topo(nodes, edges, fails, rel(path)) : [];
    if (order && order.length) {
      const preds = Object.fromEntries(Object.keys(nodes).map((n) => [n, new Set()]));
      const ancestors = Object.fromEntries(Object.keys(nodes).map((n) => [n, new Set()]));
      for (const [a, b] of edges) preds[b].add(a);
      for (const n of order) for (const p of preds[n]) for (const x of [...ancestors[p], p]) ancestors[n].add(x);
      for (const n of order) {
        const avail = new Set(inputs);
        for (const anc of ancestors[n]) for (const p of blocks[nodes[anc]].produces) avail.add(p);
        for (const need of blocks[nodes[n]].consumes) {
          if (!avail.has(need)) {
            fails.push([rel(path), `node ${JSON.stringify(n)} needs artifact ${JSON.stringify(need)}, and neither the flow inputs nor any upstream produces supply it`]);
          }
        }
      }
      if (Object.keys(nodes).length > 1) {
        const linked = new Set(edges.flat());
        for (const n of Object.keys(nodes)) if (!linked.has(n)) warns.push([rel(path), `orphan node (no edges): ${JSON.stringify(n)}`]);
      }
    }
    flows[slug] = { id: slug, path, summary: fm.summary || '', inputs: [...inputs].sort(), nodes, edges, order: order || [] };
  }
  return flows;
}

// --- commands -----------------------------------------------------------------
const load = () => { const fails = [], warns = []; const blocks = loadBlocks(fails); const flows = loadFlows(blocks, fails, warns); return { blocks, flows, fails, warns }; };

function cmdList() {
  const { blocks, flows, fails } = load();
  console.log(`=== blocks — ${Object.keys(blocks).length} ===`);
  for (const b of Object.values(blocks)) {
    const tag = b.kind === 'skill' ? `skill:${b.skill}` : 'native';
    console.log(`  ${b.id.padEnd(20)} [${tag}]${b.stop ? ' ⛔STOP' : ''}  ${b.consumes.join(',') || '∅'} -> ${b.produces.join(',') || '∅'}`);
  }
  console.log(`=== flows — ${Object.keys(flows).length} ===`);
  for (const f of Object.values(flows)) console.log(`  ${f.id.padEnd(20)} ${f.summary}`);
  if (fails.length) console.error(`(${fails.length} structural problem(s) — run \`plan-flow lint\` for detail)`);
  return 0;
}

function cmdShow(flowId) {
  const { blocks, flows } = load();
  const f = flows[flowId];
  if (!f) { console.error(`no such flow: ${JSON.stringify(flowId)} (have: ${Object.keys(flows).sort().join(', ') || 'none'})`); return 2; }
  console.log(`Flow: ${f.id} — ${f.summary}`);
  console.log(`inputs: ${f.inputs.join(', ') || '∅'}`);
  console.log('topological order:');
  f.order.forEach((n, i) => {
    const b = blocks[f.nodes[n]];
    const how = b.kind === 'skill' ? `invoke Skill \`${b.skill}\`` : 'Read the block file and follow it';
    console.log(`  ${i + 1}. [${n}] block=${b.id}${b.stop ? ' ⛔STOP' : ''} (${how})`);
    console.log(`     ${b.consumes.join(',') || '∅'} -> ${b.produces.join(',') || '∅'} | ${b.summary}`);
  });
  return 0;
}

function cmdLint(asJson) {
  const { fails, warns } = load();
  if (asJson) {
    console.log(JSON.stringify({ ok: !fails.length, failCount: fails.length, warnCount: warns.length,
      fails: fails.map(([where, msg]) => ({ where, msg })), warns: warns.map(([where, msg]) => ({ where, msg })) }, null, 2));
  } else {
    for (const [w, m] of warns) console.error(`WARN  ${w}\n      ${m}`);
    for (const [w, m] of fails) console.error(`FAIL  ${w}\n      ${m}`);
    console.error(fails.length
      ? `FAILED ${fails.length} check(s), ${warns.length} warning(s).`
      : `OK    flow lint passed (${warns.length} warning(s)).`);
  }
  return fails.length ? 1 : 0;
}

const argv = process.argv.slice(2);
const cmd = argv[0];
if (cmd === 'list') process.exit(cmdList());
else if (cmd === 'show') {
  const i = argv.indexOf('--flow');
  if (i === -1 || !argv[i + 1]) { console.error('usage: plan-flow show --flow <id>'); process.exit(2); }
  process.exit(cmdShow(argv[i + 1]));
} else if (cmd === 'lint') process.exit(cmdLint(argv.includes('--json')));
else { console.error('usage: plan-flow list | show --flow <id> | lint [--json]'); process.exit(2); }
