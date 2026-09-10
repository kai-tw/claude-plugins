#!/usr/bin/env node
// notion_payload.mjs — Archivist Notion request builder + writer.
//
// WHY THIS EXISTS
//   The KB is reached through the official `ntn` CLI (a thin wrapper over the
//   Notion REST API). A page's `properties` map still has a non-obvious wire
//   shape — title/text as rich_text arrays, select/status as {name}, multi_select
//   as [{name}], dates as {start,end}, relations as [{id}], checkboxes as bools,
//   url props under their LITERAL property name (one property is live-named
//   `userDefined:Linked Archive` — an artifact of the old MCP encoder). This
//   script is the SINGLE SOURCE OF TRUTH for that encoding and the DB registry:
//   feed it clean synthesized rows and it validates every option against the DB's
//   vocabulary, assembles the section body, and (with --commit) drives `ntn` to
//   create/update the pages.
//
//   Page BODIES stay as Markdown (the `## section` skeleton) and are written via
//   `ntn pages edit`, which converts Markdown → Notion blocks itself — so this
//   script never builds block JSON.
//
//   Plan body section definitions (description + hint + criteria) live in
//   schemas/<plan-type>.mjs — add a new plan type there, not here.
//
// USAGE
//   notion-payload create   <manifest.json | -> [--commit]   # dry-run, or create via ntn
//   notion-payload update   <manifest.json | -> [--commit]   # dry-run, or PATCH props via ntn
//   notion-payload filter   <db> Prop=Val [Prop2=Val2 …] [--json]  # build a Notion query filter
//       date props also accept <,<=,>,>= and the literal `today`, e.g. "Check Date<=today"
//   notion-payload schema   [db]                  # print embedded schema(s)
//   notion-payload hints    <db>                  # print section questionnaire
//   notion-payload template <db>                  # print a skeleton body to fill in
//   notion-payload sections <db>                  # print key::heading-regex (for scripts)
//   notion-payload criteria <db>                  # print criteria→sections routing table
//   notion-payload --help
//
//   Manifest (create):  { "db": "<key>", "rows": [ {<props + body sections | content>}, … ] }
//   Manifest (update):  { "db": "<key>", "rows": [ { "page_id": "…", <props> }, … ] }
//   `-` reads the manifest from stdin.
//
//   Reads run through `ntn datasources query <ds> --filter '<json>'` directly —
//   use the `filter` command to build the `<json>` (and to print the ds id).
//
//   ntn auth: the `ntn login` saved credentials are reused by same-user runs.
//   Override version with $NOTION_API_VERSION, token with $NOTION_API_TOKEN
//   (headless/cron). The binary is resolved from $NTN_BIN / $NTN_INSTALL_DIR /
//   ~/development/ntn, else $PATH.

import { existsSync, readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { join, resolve, isAbsolute, dirname } from 'node:path';

import { CRITERIA } from '../schemas/criteria.mjs';
import { types as productPlanTypes } from '../schemas/product-plan.mjs';
import { body as engineeringPlanBody } from '../schemas/engineering-plan.mjs';

// ── DB registry ────────────────────────────────────────────────────────────────
// Per DB: ds (data_source_id for the create parent), title (the title property name),
// props (logical name → {type, options?, notionName?}), and body (synthesis section
// skeleton, in emit order). DBs without a body take an opaque `content` string.
//
// types: title | text | select | status | multi_select | date | checkbox | relation | url
// `notionName` overrides the live Notion property name when it differs from the
// author-friendly registry key (validated against live schema via `ntn api
// v1/data_sources/<ds>`).
//
// Plan body sections (description + hint + criteria) live in schemas/<plan>.mjs.
// Body section kinds: para | bullets | table | checklist | raw
const SEL = (...o) => ({ type: 'select', options: o });
const MULTI = (...o) => ({ type: 'multi_select', options: o });

const DB = {
  'feature-archive': {
    title: 'Name',
    props: {
      Name: { type: 'title' },
      Status: SEL('Shipped', 'Abandoned', 'Superseded'),
      // Populated live from the project's own database (see PROJECT_VOCAB).
      // Empty is deliberate: if that fetch fails, every value is rejected rather
      // than silently validated against some other project's taxonomy.
      'Feature Area': MULTI(),
      'Shipped Date': { type: 'date' },
      'Security Review': { type: 'checkbox' },
      // Copied from the task at close-out — the task row is trashed there, and
      // the design trail would die with it. Empty for non-UI cycles.
      'Design Sheet': { type: 'url' },
    },
    body: [
      { key: 'Overview', kind: 'para', required: true },
      { key: 'Problem', kind: 'para', required: true },
      { key: 'Final Approach', kind: 'para', required: true },
      { key: 'Key Decisions', kind: 'bullets', required: true },
      { key: 'Deferred Items', kind: 'bullets', required: false },
    ],
  },

  'decision-log': {
    title: 'Name',
    props: {
      Name: { type: 'title' },
      Area: MULTI(), // live-populated; see PROJECT_VOCAB
      Status: SEL('Active', 'Superseded', 'Deferred'),
      Feature: { type: 'text' },
      Decided: { type: 'date' },
    },
    body: [
      { key: 'Context', kind: 'para', required: true },
      { key: 'Decision', kind: 'para', required: true },
      { key: 'Consequence', kind: 'para', required: true },
    ],
  },

  'tasklist': {
    title: 'Name',
    props: {
      Name: { type: 'title' },
      Status: SEL('In Progress', 'Next', 'Backlog', 'Deferred', 'Tracing'),
      Stage: SEL('Product Plan', 'Design Plan', 'Engineering Plan', 'Implementation', 'Review',
        'Shipped', 'Blocked', 'Translation', 'Security', 'Privacy', 'QA', 'Archived'),
      Area: MULTI(), // live-populated; see PROJECT_VOCAB
      Trigger: { type: 'text' },
      // Tracing-task fields (Status = Tracing): the next observation date + the
      // goal to evaluate against on that date.
      'Check Date': { type: 'date' },
      'Check Target': { type: 'text' },
      'Linked Archive': { type: 'url' },
      // The git-side anchor. `/plan` Step 2 opens the issue alongside the task
      // whenever the cycle will produce a PR, and the PR closes it (`Fixes #N`).
      // Empty for plan-only and Tracing rows — nothing to link.
      'GitHub Issue': { type: 'url' },
      // The design phase's render contact sheet. That phase has no plan row, so
      // this is the whole of the task's design trail; close-out copies it onto
      // the Feature Archive row before trashing the task. Empty for non-UI work.
      'Design Sheet': { type: 'url' },
    },
    // The Product/Design/Engineering Plans relations are Notion-auto-populated
    // reverse relations (the plan DBs own the Task relation) — not builder-written.
    // body: optional `content` — the `## Implementation` checklist lives here.
  },

  'product-plan': {
    title: 'Name',
    props: {
      Name: { type: 'title' },
      Status: SEL('Draft', 'Approved', 'Superseded'),
      Type: SEL('one-pager', 'prd', 'prfaq', 'strategy', 'roadmap', 'opportunity-tree', 'discovery-brief'),
      Date: { type: 'date' },
      Task: { type: 'relation', dsRef: 'tasklist' },
      'Feature Archive': { type: 'relation', dsRef: 'feature-archive' },
    },
    // Section definitions per Type live in schemas/product-plan.mjs — ADVISORY:
    // they drive `hints`, they do not gate `create`/`update` (see freeformBody).
    bodyByType: productPlanTypes,
    freeformBody: true,
  },

  'engineering-plan': {
    title: 'Name',
    props: {
      Name: { type: 'title' },
      Status: SEL('Draft', 'In Progress', 'Shipped', 'Superseded', 'Approved'),
      Date: { type: 'date' },
      Task: { type: 'relation', dsRef: 'tasklist' },
      'Feature Archive': { type: 'relation', dsRef: 'feature-archive' },
    },
    // Section definitions (description + hint + criteria) in schemas/engineering-plan.mjs — ADVISORY.
    body: engineeringPlanBody,
    freeformBody: true,
  },

  'release-log': {
    title: 'Version',
    props: {
      Version: { type: 'title' },
      Type: SEL('Major', 'Minor', 'Patch', 'Hotfix'),
      Status: SEL('In Dev', 'RC', 'Released', 'Yanked'),
      Platform: MULTI('Android', 'iOS', 'TestFlight'),
      'Release Date': { type: 'date' },
      Highlights: { type: 'text' },
    },
  },

  'analytics-catalog': {
    title: 'Event',
    props: {
      Event: { type: 'title' },
      Feature: MULTI('Cloud Sync', 'Reader', 'Books', 'Translation', 'Preference', 'Explore',
        'Homepage', 'Book Storage', 'Auth', 'Infra'),
      Kind: SEL('Built-in', 'Counter', 'Observation', 'Canary'),
      Status: SEL('Live', 'Deferred', 'Retired'),
      'Weekly Review': { type: 'checkbox' },
      Payload: { type: 'text' },
      Rationale: { type: 'text' },
    },
  },
};

const MARKER = '<!-- archivist-generated -->';

// ── errors ───────────────────────────────────────────────────────────────────
class BuildError extends Error {}
const fail = (msg) => { throw new BuildError(msg); };

// ── property encoding (standard Notion REST property JSON) ───────────────────────
// Notion caps a single rich-text object's `content` at 2000 chars — chunk longer
// strings into multiple text objects.
function richText(value) {
  const s = String(value);
  if (s.length <= 2000) return [{ text: { content: s } }];
  const out = [];
  for (let i = 0; i < s.length; i += 2000) out.push({ text: { content: s.slice(i, i + 2000) } });
  return out;
}

function encodeProp(dbKey, name, spec, value, out, rowLabel) {
  if (value === null || value === undefined) return;
  const where = `${dbKey}.${name}${rowLabel ? ` (row ${rowLabel})` : ''}`;
  const key = spec.notionName ?? name;
  switch (spec.type) {
    case 'title':
      if (typeof value !== 'string' && typeof value !== 'number')
        fail(`${where}: title must be a string${Array.isArray(value) ? ' (got an array)' : `, got ${typeof value}`}`);
      out[key] = { title: richText(value) };
      return;
    case 'text':
      if (typeof value !== 'string' && typeof value !== 'number')
        fail(`${where}: text must be a string${Array.isArray(value) ? ' (got an array — did you mean a multi-select or list section?)' : `, got ${typeof value}`}`);
      out[key] = { rich_text: richText(value) };
      return;
    case 'select':
    case 'status': {
      const v = String(value);
      if (!spec.options.includes(v))
        fail(`${where}: "${v}" is not a valid option. Valid: ${spec.options.join(', ')}`);
      out[key] = { [spec.type]: { name: v } };
      return;
    }
    case 'multi_select': {
      const arr = Array.isArray(value) ? value : fail(`${where}: multi-select must be an array, got ${typeof value}`);
      for (const v of arr)
        if (!spec.options.includes(v))
          fail(`${where}: "${v}" is not a valid option. Valid: ${spec.options.join(', ')}`);
      out[key] = { multi_select: arr.map((v) => ({ name: String(v) })) };
      return;
    }
    case 'checkbox': {
      if (typeof value !== 'boolean')
        fail(`${where}: checkbox must be true/false, got ${JSON.stringify(value)}`);
      out[key] = { checkbox: value };
      return;
    }
    case 'date': {
      const ISO = /^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}(:\d{2})?(\.\d+)?(Z|[+-]\d{2}:?\d{2})?)?$/;
      let start, end = null;
      if (typeof value === 'string') { start = value; }
      else if (value && typeof value === 'object') { start = value.start; end = value.end ?? null; }
      else fail(`${where}: date must be an ISO string or {start,end?}`);
      if (typeof start !== 'string' || !ISO.test(start))
        fail(`${where}: date start must be ISO-8601 (YYYY-MM-DD or YYYY-MM-DDThh:mm[:ss][Z]), got ${JSON.stringify(start)}`);
      if (end !== null && (typeof end !== 'string' || !ISO.test(end)))
        fail(`${where}: date end must be ISO-8601 or null, got ${JSON.stringify(end)}`);
      out[key] = { date: { start, end } };
      return;
    }
    case 'relation': {
      const arr = Array.isArray(value) ? value : [value];
      out[key] = { relation: arr.map((v) => ({ id: normalizeRelationId(String(v)) })) };
      return;
    }
    case 'url':
      out[key] = { url: String(value) };
      return;
    default:
      fail(`${where}: unknown property type "${spec.type}" in registry`);
  }
}

// Notion relations take a page id (dashed UUID). Accept a 32-hex id (with or
// without dashes) or a notion.so/app.notion.com URL whose last path segment ends
// in a 32-hex id.
function normalizeRelationId(v) {
  let hex = v;
  if (/^https?:\/\//.test(v)) {
    const m = v.replace(/[?#].*$/, '').match(/([0-9a-f]{32})$/i);
    if (!m) fail(`relation URL has no 32-hex page id: "${v}"`);
    hex = m[1];
  }
  hex = hex.replace(/-/g, '');
  if (!/^[0-9a-f]{32}$/i.test(hex))
    fail(`relation value must be a notion.so URL or a 32-hex page id, got "${v}"`);
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

// ── body assembly (Markdown; ntn pages edit converts it to blocks) ──────────────
// `description`, `hint`, and `criteria` on section definitions are metadata;
// they are not emitted into the Notion body.
function assembleBody(dbKey, body, row, rowLabel, freeform = false) {
  const parts = [MARKER];
  for (const sec of body) {
    const v = row[sec.key];
    const empty = v === undefined || v === null
      || (typeof v === 'string' && v.trim() === '')
      || (Array.isArray(v) && v.filter((x) => String(x).trim() !== '').length === 0);
    if (empty) {
      // freeformBody DBs treat `required` as advice: omit the section, don't reject.
      if (sec.required && !freeform) fail(`${dbKey}.${sec.key} (row ${rowLabel}): required body section is empty`);
      continue;
    }
    if (sec.kind === 'bullets') {
      const items = (Array.isArray(v) ? v : [v]).filter((x) => String(x).trim() !== '');
      parts.push(`## ${sec.key}\n\n${items.map((x) => `- ${String(x).trim()}`).join('\n')}`);
    } else {
      parts.push(`## ${sec.key}\n\n${String(v).trim()}`);
    }
  }
  return parts.join('\n\n') + '\n';
}

// Read a `bodyFile` (a Markdown body authored ONCE into a file — the CJK-safe
// path: the section text is never re-typed into a JSON manifest, so an LLM can't
// silently mis-type a rare hanzi at upload) and emit it VERBATIM with the marker
// prepended. For section-keyed DBs the `## ` headings are validated against the
// schema (required present, none unknown) WITHOUT touching the bytes; for content
// DBs the whole file is the body. A repo-relative path resolves against the MAIN
// worktree root (§mainRepoRoot), NOT cwd — a /plan code cycle runs from a git
// worktree whose cwd is under .claude/worktrees/, while the session-journal draft
// the bodyFile points at lives (gitignored) only in the MAIN tree.
let _mainRoot;
function mainRepoRoot() {
  // `git rev-parse --git-common-dir` returns the shared main .git even from a
  // linked worktree; its parent is the main root. Fall back to cwd if git fails.
  if (_mainRoot !== undefined) {
    return _mainRoot;
  }
  try {
    const r = spawnSync('git', ['rev-parse', '--git-common-dir'], { encoding: 'utf8' });
    _mainRoot = r.status === 0 && r.stdout.trim()
      ? dirname(resolve(r.stdout.trim()))
      : process.cwd();
  } catch {
    _mainRoot = process.cwd();
  }
  return _mainRoot;
}
function bodyFromFile(dbKey, resolvedBody, filePath, rowLabel, freeform = false) {
  let raw;
  try {
    raw = readFileSync(
      isAbsolute(filePath) ? filePath : resolve(mainRepoRoot(), filePath),
      'utf8',
    );
  } catch (e) {
    fail(`${dbKey}: bodyFile unreadable "${filePath}" (row ${rowLabel}): ${e.message}`);
  }
  raw = raw.replace(/^﻿/, '');
  const afterMarker = raw.replace(/^<!--[\s\S]*?-->\s*/, '').trimStart();
  if (/^#\s/.test(afterMarker))
    fail(`${dbKey}: bodyFile must not begin with an "# H1" (row ${rowLabel}) — the title lives in the property, not the body.`);
  // freeformBody DBs: any `## heading` is legal and nothing is mandatory — the
  // section arrays stay as `hints` guidance only. The H1 guard above still holds
  // (the title lives in the property).
  if (resolvedBody && !freeform) {
    const textKeys = new Set(resolvedBody.map((s) => s.key));
    const seen = new Set();
    for (const m of raw.matchAll(/^##\s+(.+?)\s*$/gm)) {
      const key = m[1].trim();
      if (!textKeys.has(key))
        fail(`${dbKey}: bodyFile has unknown section "## ${key}" (row ${rowLabel}). Known: ${[...textKeys].join(', ')}`);
      seen.add(key);
    }
    for (const s of resolvedBody)
      if (s.required && !seen.has(s.key))
        fail(`${dbKey}: bodyFile missing required section "## ${s.key}" (row ${rowLabel})`);
  }
  warnHalfWidth(raw, `${dbKey} row ${rowLabel}`);
  let md = raw.replace(/\s+$/, '') + '\n';
  if (!md.startsWith('<!--')) md = `${MARKER}\n\n${md}`;
  return md;
}

// ── half-width punctuation in CJK prose (house-rules §Communication & scope) ──
// 「逗號請用全形」. Plan bodies are the one surface where this is mechanically
// checkable — chat and commit messages have no equivalent gate — so the check
// lives here, at the moment the body is about to become a Notion page.
//
// WARNS, never fails. Measured against every real plan body in both projects:
// after masking, the survivors split into unambiguous violations
// (`(NEW，搬移＋分群)`) and calls a reasonable author would defend — `O(檔案數 ×
// 規則數)` is maths, and a bilingual user story (`As a 專員, I want to …`) is an
// English sentence with CJK filled in. Blocking an upload on those would cost
// more than the rule returns; printing them at the moment of authoring does not.
const CJK_CLASS = '\\u3400-\\u4dbf\\u4e00-\\u9fff';
const CJK_CHAR = new RegExp(`[${CJK_CLASS}]`);
const HW_PAIRED = { '(': '（', ')': '）' };
const HW_TRAILING = { ',': '，', ';': '；', ':': '：', '!': '！', '?': '？', '.': '。' };

// Blank out spans where ASCII punctuation is correct by rule — fenced and inline
// code, HTML comments, link targets, bare URLs. Replaced space-for-character so
// the reported line:col still points at the real source position.
function maskAsciiExempt(s) {
  const blank = (m) => m.replace(/[^\n]/g, ' ');
  return s
    .replace(/```[\s\S]*?```/g, blank)
    .replace(/`[^`\n]*`/g, blank)
    .replace(/<!--[\s\S]*?-->/g, blank)
    .replace(/\]\([^)\n]*\)/g, blank)
    .replace(/\bhttps?:\/\/\S+/g, blank)
    // The user-story line is an ENGLISH sentence with CJK slotted in, and this
    // same plugin mandates it verbatim — `schemas/product-plan.mjs` §User
    // stories: 「格式（verbatim）：As a <persona>, I want to <action> so that
    // <outcome>」. Warning about the commas the schema requires would be the
    // plugin contradicting itself, and it was every hit on one real PM plan.
    .replace(/^.*\bAs an? .*\bI want\b.*$/gm, blank);
}

function warnHalfWidth(raw, label) {
  const masked = maskAsciiExempt(raw);
  const rawLines = raw.split('\n');
  const hits = [];
  masked.split('\n').forEach((line, li) => {
    for (let i = 0; i < line.length; i++) {
      const ch = line[i];
      const prev = line[i - 1] ?? '';
      const next = line[i + 1] ?? '';
      let bad = false;
      // Brackets and the period are judged on their LEFT only: `O(檔案數)` is
      // maths and `0.18.0` is a version, and neither is a CJK separator — but a
      // genuinely mis-set pair still trips on its closing bracket.
      if (ch in HW_PAIRED || ch === '.') bad = CJK_CHAR.test(prev);
      else if (ch in HW_TRAILING) bad = CJK_CHAR.test(prev) || CJK_CHAR.test(next);
      if (bad) hits.push({ line: li + 1, col: i + 1, ch, want: HW_PAIRED[ch] ?? HW_TRAILING[ch], text: rawLines[li].trim().slice(0, 80) });
    }
  });
  if (!hits.length) return;
  console.error(`⚠ ${label}: ${hits.length} half-width punctuation mark(s) touching CJK`
    + ` — 繁體中文 prose uses ，。：；！？（）(house-rules §Communication & scope):`);
  for (const h of hits.slice(0, 12))
    console.error(`    ${h.line}:${h.col}  ${h.ch} → ${h.want}   ${h.text}`);
  if (hits.length > 12) console.error(`    … ${hits.length - 12} more`);
}

// ── per-row build ────────────────────────────────────────────────────────────
// create → { title, apiBody: {parent, properties, icon?, cover?}, markdown? }
// update → { page_id, properties, markdown? }  (markdown only when bodyFile given)
function buildRow(dbKey, def, row, mode) {
  const rowLabel = row[def.title] ?? row.page_id ?? '?';
  const properties = {};

  // Resolve body section array: flat (def.body) or type-indexed (def.bodyByType[row.Type])
  let resolvedBody = def.body ?? null;
  if (def.bodyByType) {
    const type = row.Type;
    if (!type) fail(`${dbKey}: rows require a "Type" field to select the body section template (row ${rowLabel})`);
    resolvedBody = def.bodyByType[type];
    if (!resolvedBody) fail(`${dbKey}: unknown Type "${type}". Valid: ${Object.keys(def.bodyByType).join(', ')} (row ${rowLabel})`);
  }

  const bodyKeys = new Set((resolvedBody ?? []).map((s) => s.key));
  const reserved = new Set([...Object.keys(def.props), ...bodyKeys, 'content', 'bodyFile', 'page_id', 'icon', 'cover']);

  // On a freeformBody DB an unrecognised key is an ad hoc section, not an error.
  if (!def.freeformBody)
    for (const k of Object.keys(row))
      if (!reserved.has(k))
        fail(`${dbKey}: unknown field "${k}" (row ${rowLabel}). Known: ${[...reserved].filter((x) => x !== 'page_id' && x !== 'icon' && x !== 'cover').join(', ')}`);

  for (const [name, spec] of Object.entries(def.props))
    encodeProp(dbKey, name, spec, row[name], properties, rowLabel);

  const titleKey = def.props[def.title]?.notionName ?? def.title;
  if (mode === 'create' && properties[titleKey] === undefined)
    fail(`${dbKey}: missing required title "${def.title}" (row ${rowLabel})`);

  // Body source: inline section fields, an opaque `content` string, OR a
  // `bodyFile` (the CJK-safe path — author once, upload byte-exact).
  const hasBodyFile = row.bodyFile != null && String(row.bodyFile).trim() !== '';
  const hasInlineSections = !!resolvedBody && [...bodyKeys].some((k) => k in row);
  const hasOpaqueContent = !resolvedBody && 'content' in row;

  if (resolvedBody && 'content' in row)
    fail(`${dbKey}: pass body SECTION fields (${[...bodyKeys].join(', ')}) or a "bodyFile", not a raw "content" string (row ${rowLabel})`);
  if (hasBodyFile && (hasInlineSections || hasOpaqueContent))
    fail(`${dbKey}: "bodyFile" is exclusive with inline body sections / "content" (row ${rowLabel}) — author the WHOLE text body in the file.`);
  // On UPDATE a body edit is allowed ONLY via bodyFile — reject an inline-body
  // update BEFORE assembling (else assembleBody's required-section error masks
  // the real "properties-only" reason).
  if (mode === 'update' && (hasInlineSections || hasOpaqueContent) && !hasBodyFile)
    fail(`${dbKey}: update sets PROPERTIES only unless you pass a "bodyFile" (row ${rowLabel}) — `
      + `author the body in the file and re-point bodyFile; inline body edits on update are refused.`);

  // Assemble the text body from whichever source is present.
  let markdown;
  if (hasBodyFile) {
    markdown = bodyFromFile(dbKey, resolvedBody, String(row.bodyFile), rowLabel, !!def.freeformBody);
  } else if (resolvedBody && hasInlineSections) {
    markdown = assembleBody(dbKey, resolvedBody, row, rowLabel, !!def.freeformBody);
  } else if (hasOpaqueContent) {
    markdown = String(row.content).trim();
    const firstLine = markdown.replace(/^<!--[\s\S]*?-->\s*/, '').trimStart();
    if (/^#\s/.test(firstLine))
      fail(`${dbKey}: "content" must not begin with an "# H1" (row ${rowLabel}) — the page title lives in the title property, not the body.`);
    if (!markdown.startsWith('<!--')) markdown = `${MARKER}\n\n${markdown}`;
  }

  if (mode === 'update') {
    if (!row.page_id) fail(`${dbKey}: update rows need a "page_id" (row ${rowLabel})`);
    // (inline-body-on-update already rejected above, before assembly)
    return { page_id: row.page_id, properties, markdown: hasBodyFile ? markdown : undefined };
  }

  const apiBody = { parent: { type: 'data_source_id', data_source_id: def.ds }, properties };
  if (row.icon) apiBody.icon = row.icon;
  if (row.cover) apiBody.cover = row.cover;
  return { title: String(rowLabel), apiBody, markdown };
}

// ── manifest → payload ─────────────────────────────────────────────────────────
function build(manifest, mode) {
  if (!manifest || typeof manifest !== 'object') fail('manifest must be a JSON object');
  const dbKey = manifest.db;
  const def = DB[dbKey];
  if (!def) fail(unknownDb(dbKey));
  const rows = manifest.rows;
  if (!Array.isArray(rows) || rows.length === 0) fail('manifest.rows must be a non-empty array');
  return { dbKey, rows: rows.map((r) => buildRow(dbKey, def, r, mode)) };
}

// ── ntn driver (only used for --commit) ─────────────────────────────────────────
function resolveNtn() {
  const candidates = [];
  if (process.env.NTN_BIN) candidates.push(process.env.NTN_BIN);
  if (process.env.NTN_INSTALL_DIR) candidates.push(join(process.env.NTN_INSTALL_DIR, 'ntn'));
  if (process.env.HOME) candidates.push(join(process.env.HOME, 'development', 'ntn', 'ntn'));
  for (const p of candidates) if (existsSync(p)) return p;
  return 'ntn'; // rely on PATH
}
const NTN = resolveNtn();

function ntn(args, input) {
  const r = spawnSync(NTN, args, { input, encoding: 'utf8', maxBuffer: 1 << 26 });
  if (r.error) fail(`ntn ${args.join(' ')}: ${r.error.code === 'ENOENT' ? `binary not found (set $NTN_BIN or add ~/development/ntn to PATH)` : r.error.message}`);
  if (r.status !== 0) fail(`ntn ${args.join(' ')} exited ${r.status}: ${(r.stderr || '').trim()}`);
  return r.stdout;
}

// ── Iron Law 2 verify: did the body we just wrote land IN FULL? ──────────────
// The marker alone cannot answer that. It is PREPENDED, so a write that lands the
// head and drops the tail keeps it and reports ✓ — which is exactly the shape of
// a truncated write we hit once: a long body went out, roughly a third of its
// blocks arrived, and it stopped mid-document. Cause never established, which is
// the point — the check has to catch the shape, not the cause. The body goes
// through ONE `ntn pages edit`, so there is no chunk
// loop to bound the damage either. So check that every `## ` section arrived,
// which catches a head, middle, or tail loss alike. A body with no headings falls
// back to the marker-only check — no regression, and comparing prose Notion is
// free to reformat would only produce false alarms.
//
// Notion returns the body escaped: markdown specials come back backslashed, and
// non-ASCII may come back as \uXXXX. Normalize both sides before comparing.
function unescapeNotion(s) {
  return s.replace(/\\u([0-9a-fA-F]{4})/g, (_, h) => String.fromCharCode(parseInt(h, 16)))
          .replace(/\\/g, '');
}

function verifyBody(markdown, got) {
  const flat = unescapeNotion(got);
  if (!flat.includes(MARKER)) return 'NO-MARKER';
  const heads = [...markdown.matchAll(/^##\s+(.+?)\s*$/gm)].map((m) => unescapeNotion(m[1].trim()));
  const missing = heads.filter((h) => !flat.includes(`## ${h}`));
  if (!missing.length) return 'ok';
  return `TRUNCATED ${heads.length - missing.length}/${heads.length} sections`
    + ` (missing: ${missing.slice(0, 3).join(', ')}${missing.length > 3 ? ', …' : ''})`;
}

function commitCreate(dbKey, built) {
  const results = [];
  let bad = 0;
  for (const { title, apiBody, markdown } of built) {
    const created = JSON.parse(ntn(['api', 'v1/pages', '-X', 'POST'], JSON.stringify(apiBody)));
    const id = created.id;
    const url = created.url || created.public_url || '';
    if (!id) fail(`create "${title}": response had no page id`);
    if (markdown) ntn(['pages', 'edit', id], markdown);
    // Verify (Iron Law 2): confirm the row exists and (if a body was written) landed whole.
    const got = ntn(['pages', 'get', id]);
    const state = markdown ? verifyBody(markdown, got) : '(none)';
    if (state !== 'ok' && state !== '(none)') bad++;
    results.push({ title, id, url, body: state });
    console.error(`✓ ${dbKey}: ${title} → ${url}${state === 'ok' || state === '(none)' ? '' : `  ⚠ ${state}`}`);
  }
  console.log(JSON.stringify(results, null, 2));
  reportVerifyFailures(bad, built.length);
}

// A failed verify must not read as success. Exit non-zero AFTER the batch (never
// mid-loop: aborting leaves the remaining rows half-written and unreported), so
// the caller cannot mark `plan-cycle uploaded` off a write that did not land.
function reportVerifyFailures(bad, total) {
  if (!bad) return;
  console.error(`✗ ${bad}/${total} row(s) failed the Iron-Law-2 body verify — re-write the body`
    + ` and re-verify BEFORE marking anything uploaded or trashing any source.`);
  process.exitCode = 1;
}

function commitUpdate(dbKey, built) {
  const results = [];
  let bad = 0;
  for (const { page_id, properties, markdown } of built) {
    // Properties (skip an empty PATCH — a bodyFile-only update touches no props).
    if (Object.keys(properties).length)
      JSON.parse(ntn(['api', `v1/pages/${page_id}`, '-X', 'PATCH'], JSON.stringify({ properties })));
    // Body: full-replace from the bodyFile (the file is the single source of truth),
    // then verify it landed whole (Iron Law 2).
    let bodyState = '(unchanged)';
    let ok = true;
    if (markdown) {
      ntn(['pages', 'edit', page_id], markdown);
      const got = ntn(['pages', 'get', page_id]);
      const state = verifyBody(markdown, got);
      ok = state === 'ok';
      bodyState = ok ? 'replaced' : state;
      if (!ok) bad++;
    }
    results.push({ page_id, props: Object.keys(properties), body: bodyState });
    console.error(`✓ ${dbKey}: updated ${page_id} (${Object.keys(properties).join(', ') || 'no props'})`
      + `${markdown ? `  + body ${bodyState}${ok ? '' : ' ⚠'}` : ''}`);
  }
  console.log(JSON.stringify(results, null, 2));
  reportVerifyFailures(bad, built.length);
}

// ── trash a page (close-out) ─────────────────────────────────────────────────
// Iron Law 7 guard: refuse to trash a page that lacks the archivist marker (it
// would be hand-authored). Dry-run by default; --commit actually trashes.
function trashPage(pageId, commit) {
  const got = ntn(['pages', 'get', pageId]);
  const marked = got.replace(/\\/g, '').includes(MARKER);
  if (!marked)
    fail(`refusing to trash ${pageId}: no "${MARKER}" marker — it looks hand-authored (Iron Law 7). `
      + `If you are certain, trash it by hand: ntn pages trash ${pageId} --yes`);
  if (!commit) { console.log(`would trash ${pageId} (archivist marker present). Re-run with --commit.`); return; }
  ntn(['pages', 'trash', pageId, '--yes']);
  console.error(`✓ trashed ${pageId}`);
  console.log(JSON.stringify({ trashed: pageId }, null, 2));
}

// ── block-level editing (toggle a checklist box; append blocks) ───────────────
function getAllChildren(blockId) {
  const out = [];
  let cursor = null;
  do {
    const args = ['api', `v1/blocks/${blockId}/children`, 'page_size==100'];
    if (cursor) args.push(`start_cursor==${cursor}`);
    const res = JSON.parse(ntn(args));
    out.push(...(res.results || []));
    cursor = res.has_more ? res.next_cursor : null;
  } while (cursor);
  return out;
}

const todoText = (b) => (b.to_do?.rich_text || []).map((r) => r.plain_text ?? r.text?.content ?? '').join('');

// Toggle a single `to_do` block (Implementation checklist) without re-sending the
// whole page body. Matches by substring; refuses an ambiguous match.
function checkBox(pageId, match, uncheck, commit) {
  const todos = getAllChildren(pageId).filter((b) => b.type === 'to_do');
  const hits = todos.filter((b) => todoText(b).toLowerCase().includes(match.toLowerCase()));
  if (hits.length === 0) fail(`check: no to_do on ${pageId} matching "${match}" (found ${todos.length} to_do block(s))`);
  if (hits.length > 1) fail(`check: "${match}" matches ${hits.length} to_do blocks — be more specific:\n${hits.map((h) => `  • ${todoText(h)}`).join('\n')}`);
  const block = hits[0];
  const target = !uncheck;
  if (block.to_do.checked === target) { console.log(`already ${target ? 'checked' : 'unchecked'}: "${todoText(block)}"`); return; }
  if (!commit) { console.log(`would ${target ? 'check' : 'uncheck'} "${todoText(block)}" (${block.id}). Re-run with --commit.`); return; }
  ntn(['api', `v1/blocks/${block.id}`, '-X', 'PATCH'], JSON.stringify({ to_do: { checked: target } }));
  console.error(`✓ ${target ? 'checked' : 'unchecked'} "${todoText(block)}"`);
  console.log(JSON.stringify({ block: block.id, checked: target }, null, 2));
}

// Bounded Markdown → Notion block objects: heading_1-3, paragraph,
// bulleted/numbered list, to_do, and pipe-tables (→ a new table block). NOT a
// general Markdown engine — full bodies still go through `ntn pages edit`.
function mdToBlocks(md) {
  const lines = md.replace(/\r\n/g, '\n').split('\n');
  const blocks = [];
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    if (line.trim() === '') { i++; continue; }
    if (/^\s*\|.*\|\s*$/.test(line)) {
      const raw = [];
      while (i < lines.length && /^\s*\|.*\|\s*$/.test(lines[i])) { raw.push(lines[i]); i++; }
      const rows = raw
        .filter((r) => !/^\s*\|[\s:|-]+\|\s*$/.test(r)) // drop the |---|---| separator
        .map((r) => r.trim().replace(/^\|/, '').replace(/\|$/, '').split('|').map((c) => c.trim()));
      if (rows.length) {
        const width = Math.max(...rows.map((c) => c.length));
        blocks.push({
          object: 'block', type: 'table',
          table: {
            table_width: width, has_column_header: true, has_row_header: false,
            children: rows.map((row) => ({
              object: 'block', type: 'table_row',
              table_row: { cells: Array.from({ length: width }, (_, k) => richText(row[k] ?? '')) },
            })),
          },
        });
      }
      continue;
    }
    let m;
    if ((m = line.match(/^(#{1,3})\s+(.*)$/))) {
      const t = `heading_${m[1].length}`;
      blocks.push({ object: 'block', type: t, [t]: { rich_text: richText(m[2]) } });
      i++; continue;
    }
    if ((m = line.match(/^\s*[-*]\s+\[([ xX])\]\s+(.*)$/))) {
      blocks.push({ object: 'block', type: 'to_do', to_do: { rich_text: richText(m[2]), checked: m[1].toLowerCase() === 'x' } });
      i++; continue;
    }
    if ((m = line.match(/^\s*[-*]\s+(.*)$/))) {
      blocks.push({ object: 'block', type: 'bulleted_list_item', bulleted_list_item: { rich_text: richText(m[1]) } });
      i++; continue;
    }
    if ((m = line.match(/^\s*\d+\.\s+(.*)$/))) {
      blocks.push({ object: 'block', type: 'numbered_list_item', numbered_list_item: { rich_text: richText(m[1]) } });
      i++; continue;
    }
    const buf = [line]; i++;
    while (i < lines.length && lines[i].trim() !== '' && !/^\s*(#{1,3}\s|[-*]\s|\d+\.\s|\|)/.test(lines[i])) { buf.push(lines[i]); i++; }
    blocks.push({ object: 'block', type: 'paragraph', paragraph: { rich_text: richText(buf.join('\n')) } });
  }
  return blocks;
}

// Append blocks to a page body (PATCH …/children), chunked ≤100 per call.
function appendBlocks(pageId, blocks, commit) {
  if (!blocks.length) fail('append: no blocks parsed from input');
  if (!commit) { console.log(JSON.stringify({ would_append: blocks.length, blocks }, null, 2)); return; }
  let appended = 0;
  for (let k = 0; k < blocks.length; k += 100) {
    const chunk = blocks.slice(k, k + 100);
    ntn(['api', `v1/blocks/${pageId}/children`, '-X', 'PATCH'], JSON.stringify({ children: chunk }));
    appended += chunk.length;
  }
  console.error(`✓ appended ${appended} block(s) to ${pageId}`);
  console.log(JSON.stringify({ appended, page: pageId }, null, 2));
}

// ── comment on a page (e.g. review findings) ──────────────────────────────────
function postComment(pageId, text, commit) {
  if (!text || !text.trim()) fail('comment: empty text');
  if (!commit) { console.log(`would comment on ${pageId}:\n${text.slice(0, 400)}${text.length > 400 ? '…' : ''}`); return; }
  const res = JSON.parse(ntn(['api', 'v1/comments', '-X', 'POST'], JSON.stringify({ parent: { page_id: pageId }, rich_text: richText(text) })));
  console.error(`✓ commented on ${pageId}`);
  console.log(JSON.stringify({ comment: res.id, page: pageId }, null, 2));
}

// ── filter builder ──────────────────────────────────────────────────────────────
// `filter <db> Prop=Val …` → a Notion query filter, using the registry to pick the
// right operator per property type. Read still runs through `ntn datasources query`.
// Date properties also accept the comparison operators `<`, `<=`, `>`, `>=`
// (e.g. `"Check Date<=today"` for overdue+due), and the literal `today` on either
// side of the operator resolves to the system's local date.
const DATE_OP = { '<': 'before', '<=': 'on_or_before', '>': 'after', '>=': 'on_or_after' };
const todayISO = () => {
  const d = new Date();
  return new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 10);
};
function buildFilter(dbKey, pairs) {
  const def = DB[dbKey];
  if (!def) fail(unknownDb(dbKey));
  if (pairs.length === 0) fail('filter needs at least one Prop=Val');
  const clauses = pairs.map((p) => {
    // Property names never contain <, >, =, so the first such char is the operator.
    const m = p.match(/^([^<>=]+)(<=|>=|<|>|=)(.*)$/);
    if (!m) fail(`bad filter clause "${p}", expected Prop=Val (date props also accept <,<=,>,>=)`);
    const [, name, op, rawVal] = m;
    let val = rawVal;
    const spec = def.props[name];
    if (!spec) fail(`${dbKey}: unknown property "${name}". Known: ${Object.keys(def.props).join(', ')}`);
    const property = spec.notionName ?? name;
    if (op !== '=' && spec.type !== 'date')
      fail(`${dbKey}.${name}: operator "${op}" only applies to date properties (type is "${spec.type}")`);
    const validate = () => {
      if (spec.options && !spec.options.includes(val))
        fail(`${dbKey}.${name}: "${val}" is not a valid option. Valid: ${spec.options.join(', ')}`);
    };
    switch (spec.type) {
      case 'select': validate(); return { property, select: { equals: val } };
      case 'status': validate(); return { property, status: { equals: val } };
      case 'multi_select': validate(); return { property, multi_select: { contains: val } };
      case 'checkbox': return { property, checkbox: { equals: val === 'true' || val === '1' } };
      case 'date': {
        if (val === 'today') val = todayISO();
        else if (!/^\d{4}-\d{2}-\d{2}/.test(val))
          fail(`${dbKey}.${name}: date value "${val}" must be YYYY-MM-DD or "today"`);
        return { property, date: { [DATE_OP[op] ?? 'equals']: val } };
      }
      case 'url': return { property, url: { equals: val } };
      case 'title': return { property, title: { contains: val } };
      case 'text': return { property, rich_text: { contains: val } };
      case 'relation': fail(`${dbKey}.${name}: relation filters are not supported by this helper`);
      default: fail(`${dbKey}.${name}: cannot filter on type "${spec.type}"`);
    }
  });
  return { ds: def.ds, filter: clauses.length === 1 ? clauses[0] : { and: clauses } };
}

function printFilter(dbKey, pairs, jsonOnly) {
  const { ds, filter } = buildFilter(dbKey, pairs);
  const json = JSON.stringify(filter);
  if (jsonOnly) { console.log(json); return; }
  console.log(`ds:     ${ds}`);
  console.log(`filter: ${json}`);
  console.log(`\nrun:\n  ntn datasources query ${ds} --filter '${json}' --json`);
}

// ── schema printer ─────────────────────────────────────────────────────────────
function printSchema(only) {
  const keys = only ? [only] : Object.keys(DB);
  for (const k of keys) {
    const def = DB[k];
    if (!def) { console.error(unknownDb(k)); process.exitCode = 1; return; }
    console.log(`\n${k}  (parent data_source_id: ${def.ds ?? '— pass --root to resolve'})`);
    console.log(`  title: ${def.title}`);
    console.log('  properties:');
    for (const [name, spec] of Object.entries(def.props)) {
      const opts = spec.options ? ` — ${spec.options.join(' | ')}` : '';
      const alias = spec.notionName ? ` (notion: ${spec.notionName})` : '';
      console.log(`    ${name.padEnd(16)} ${spec.type}${opts}${alias}`);
    }
    if (def.body) {
      console.log('  body sections:');
      for (const s of def.body) {
        const req = s.required ? '(required)' : '(optional)';
        const crit = s.criteria && s.criteria.length
          ? `  [criteria: ${s.criteria.map((k) => { const c = CRITERIA[k]; return c ? `${c.n}` : k; }).join(', ')}]`
          : '';
        console.log(`    ## ${s.key}  [${s.kind}] ${req}${crit}`);
        if (s.description) console.log(`       ↳ ${s.description}`);
      }
    } else if (def.bodyByType) {
      console.log('  body sections (by Type):');
      for (const [t, sections] of Object.entries(def.bodyByType)) {
        console.log(`    [${t}]`);
        for (const s of sections) {
          const req = s.required ? '(required)' : '(optional)';
          console.log(`      ## ${s.key}  [${s.kind}] ${req}`);
          if (s.description) console.log(`         ↳ ${s.description}`);
        }
      }
    } else {
      console.log('  body: opaque "content" string (authoring role owns it)');
    }
  }
}

// ── live schema drift check ──────────────────────────────────────────────────
const REGISTRY_TO_NOTION = {
  title: 'title', text: 'rich_text', select: 'select', status: 'status',
  multi_select: 'multi_select', date: 'date', checkbox: 'checkbox',
  relation: 'relation', url: 'url',
};

// Fetch each DB's live data-source schema and diff property names / types / option
// vocab against the registry. Exit 3 on any drift. (Automates the migration's
// manual reconcile.)
function schemaLive(only) {
  const keys = only ? [only] : Object.keys(DB);
  let anyDrift = false;
  for (const k of keys) {
    const def = DB[k];
    if (!def) { console.error(unknownDb(k)); process.exitCode = 1; return; }
    const live = JSON.parse(ntn(['api', `v1/data_sources/${def.ds}`]));
    const liveProps = live.properties || {};
    const drift = [];
    for (const [name, spec] of Object.entries(def.props)) {
      const liveName = spec.notionName ?? name;
      const lp = liveProps[liveName];
      if (!lp) { drift.push(`MISSING in Notion: "${liveName}" (registry key ${name})`); continue; }
      const want = REGISTRY_TO_NOTION[spec.type];
      if (lp.type !== want) drift.push(`TYPE "${liveName}": registry ${want} vs live ${lp.type}`);
      if (spec.options) {
        const liveOpts = (lp[lp.type]?.options || []).map((o) => o.name);
        const missing = spec.options.filter((o) => !liveOpts.includes(o));
        const extra = liveOpts.filter((o) => !spec.options.includes(o));
        if (missing.length) drift.push(`OPTIONS "${liveName}" — in registry, not live: ${missing.join(', ')}`);
        if (extra.length) drift.push(`OPTIONS "${liveName}" — live, not in registry: ${extra.join(', ')}`);
      }
    }
    const known = new Set(Object.entries(def.props).map(([n, s]) => s.notionName ?? n));
    known.add(def.title);
    // Reverse-relation props (e.g. TaskList's Plans back-refs) are Notion-managed +
    // unmanaged by the builder — don't flag them; only surface untracked NON-relations.
    const extraProps = Object.keys(liveProps).filter((n) => !known.has(n) && liveProps[n].type !== 'relation');
    if (extraProps.length) drift.push(`UNTRACKED live props (informational): ${extraProps.join(', ')}`);
    if (drift.length) { anyDrift = true; console.log(`\n${k} (ds ${def.ds}) — DRIFT:`); for (const d of drift) console.log(`  • ${d}`); }
    else console.log(`${k} — ✓ in sync`);
  }
  if (anyDrift) process.exitCode = 3;
}

// ── hints printer ──────────────────────────────────────────────────────────────
function printSectionList(dbKey, typeKey, sections) {
  console.log(`# ${dbKey}${typeKey ? ` (${typeKey})` : ''} — body section questionnaire\n`);
  console.log(`Fill each section below and pass it as the matching key in the manifest row.\n`);
  for (const s of sections) {
    const req = s.required ? 'required' : 'optional';
    console.log(`${'─'.repeat(72)}`);
    console.log(`## ${s.key}  [kind: ${s.kind}] (${req})`);
    if (s.description) console.log(`\nDescription: ${s.description}`);
    if (s.criteria && s.criteria.length > 0) {
      const labels = s.criteria.map((k) => { const c = CRITERIA[k]; return c ? `${c.n} ${c.label}` : k; }).join(', ');
      console.log(`Criteria:    ${labels}`);
    }
    if (s.hint) console.log(`\nHint:\n${s.hint.split('\n').map((l) => `  ${l}`).join('\n')}`);
    console.log('');
  }
}

// Shared lookup for `hints` / `sections` / `template` — one resolver so the
// three can never disagree about which sections a db+type has.
// Returns the section array, or null after printing the error (exit code set).
function resolveSections(dbKey, typeKey, cmd) {
  if (!dbKey) { console.error(`${cmd} requires a db argument. Valid: ` + Object.keys(DB).join(', ')); process.exitCode = 1; return null; }
  const def = DB[dbKey];
  if (!def) { console.error(unknownDb(dbKey)); process.exitCode = 1; return null; }

  if (def.bodyByType) {
    if (!typeKey) {
      console.error(`"${dbKey}" has one body structure per Type. Valid: ${Object.keys(def.bodyByType).join(', ')}`);
      console.error(`Usage: notion-payload ${cmd} ${dbKey} <type>`);
      process.exitCode = 1; return null;
    }
    const sections = def.bodyByType[typeKey];
    if (!sections) { console.error(`unknown type "${typeKey}" for "${dbKey}". Valid: ${Object.keys(def.bodyByType).join(', ')}`); process.exitCode = 1; return null; }
    return sections;
  }

  if (!def.body) { console.error(`"${dbKey}" has no structured body sections (opaque content — the authoring role owns it).`); process.exitCode = 1; return null; }
  return def.body;
}

function printHints(dbKey, typeKey) {
  const def = dbKey ? DB[dbKey] : null;
  // `hints` with no type on a by-Type db lists the types instead of erroring —
  // it is the discovery entry point the authoring roles call first.
  if (def?.bodyByType && !typeKey) {
    console.log(`# ${dbKey} — body section questionnaire\n`);
    console.log(`This DB has multiple body structures by Type. Available types:\n`);
    for (const [t, sections] of Object.entries(def.bodyByType))
      console.log(`  ${t.padEnd(20)} ${sections.map((s) => s.key).join(' · ')}`);
    console.log(`\nUsage: notion-payload hints ${dbKey} <type>`);
    return;
  }
  const sections = resolveSections(dbKey, typeKey, 'hints');
  if (!sections) return;
  printSectionList(dbKey, typeKey ?? null, sections);
}

// ── sections printer (machine-readable; plan_lint.sh consumes this) ───────────
// One line per section: `<key>::<heading regex>`. The regex ORs the English key
// with the section's `aliases` — headings are translated to 繁體中文 per the
// authoring skill's §Language, so an English-only match would false-negative.
// This exists so nothing outside schemas/ keeps its own copy of the section
// list; that duplication is what let a retired section linger in the linter.
function printSections(dbKey, typeKey) {
  const sections = resolveSections(dbKey, typeKey, 'sections');
  if (!sections) return;
  for (const s of sections)
    console.log(`${s.key}::${[s.key, ...(s.aliases ?? [])].join('|')}`);
}

// ── template printer ──────────────────────────────────────────────────────────
// A skeleton body to fill in. `hints` states the per-section rules (including
// the 禁-lists, which an example cannot show); this shows the SHAPE — heading
// order, the density I3 asks for, and where an I4 decision note goes.
const STUB = {
  para: '<一句話說完；講不完才第二句>',
  bullets: '- <一條一個裁定或事實>\n- <同上>',
  table: '| <欄> | <欄> |\n|---|---|\n| <值> | <值> |',
  checklist: '- [ ] <可勾掉的一件事>',
  raw: '<依 hints 的結構填>',
};

function printTemplate(dbKey, typeKey) {
  const sections = resolveSections(dbKey, typeKey, 'template');
  if (!sections) return;
  console.log(`<!-- ${dbKey}${typeKey ? ` (${typeKey})` : ''} skeleton.`);
  console.log(`     Per-section rules + 禁-lists: notion-payload hints ${dbKey}${typeKey ? ` ${typeKey}` : ''}`);
  console.log(`     I3 — 條列為主，每行都要答得出「我承載哪個裁定或事實」，答不出來就刪.`);
  console.log(`     I4 — 裁定的那一行下面附一行：〔自行裁定〕+理由，或 〔使用者〕「逐字原話」→ 本輪怎麼落地；引號內是原話，不得改寫.`);
  console.log(`     Delete every placeholder and this comment before saving. -->`);
  for (const s of sections) {
    console.log(`\n## ${s.key}${s.required ? '' : '   <!-- optional; delete if 不適用 -->'}`);
    // A section's own `template` wins; the kind-based stub is the fallback for
    // sections that have not authored one.
    console.log(s.template ?? STUB[s.kind] ?? STUB.raw);
  }
  // The example must not start any line with `#` — a template whose comment
  // survives into the body would otherwise register a phantom heading with
  // every tool that greps for `^## `, plan_lint.sh included.
  console.log(`\n<!-- 決策註記範例（放在被裁定的那一行正下方，不要集中在一處）：`);
  console.log(`     | \`ReaderShell\` | 承載分頁與捲動位置 | 既有 |`);
  console.log(`     〔自行裁定〕沿用 ReaderShell 而非新增 wrapper——它已持有捲動位置，新增等於第二真相源。 -->`);
}

// ── criteria printer ──────────────────────────────────────────────────────────
function printCriteria(dbKey) {
  if (!dbKey) { console.error('criteria requires a db argument. Valid: ' + Object.keys(DB).join(', ')); process.exitCode = 1; return; }
  const def = DB[dbKey];
  if (!def) { console.error(unknownDb(dbKey)); process.exitCode = 1; return; }
  if (!def.body) { console.error(`"${dbKey}" has no structured body sections with criteria.`); process.exitCode = 1; return; }

  const map = {};
  for (const s of def.body)
    for (const c of (s.criteria ?? [])) {
      if (!map[c]) map[c] = [];
      map[c].push(s.key);
    }

  console.log(`# ${dbKey} — criteria routing\n`);
  console.log(`Criterion → which gate grades it → plan section(s) where it is earned.`);
  console.log(`  plan = engineer-plan-reviewer, before code (rubric: engineer-plan-reviewer.md §Criterion N)`);
  console.log(`  diff = code-reviewer, on real code (rule: the owning .claude/rules/ file)`);
  console.log(`  pre-pass = a named agent's verdict, carried into the report intact\n`);
  console.log(`| Criterion | Graded on | Earned in plan section(s) |`);
  console.log(`|---|---|---|`);
  for (const [key, crit] of Object.entries(CRITERIA)) {
    const sections = (map[key] ?? []).map((s) => `§${s}`).join(', ') || '*(cross-cutting)*';
    console.log(`| ${crit.n} — ${crit.label} | ${crit.where ?? '?'} | ${sections} |`);
  }
}

const HELP = `notion-payload — Archivist Notion request builder + writer (via the ntn CLI)

  notion-payload create   <manifest.json | -> [--commit]   dry-run, or create pages via ntn
  notion-payload update   <manifest.json | -> [--commit]   dry-run, or PATCH properties via ntn
  notion-payload set      <db> <page-id> Prop=Val […] [--commit]     one-row property flip, no manifest
  notion-payload filter   <db> Prop=Val […] [--json]       build a Notion query filter (+ ds id)
  notion-payload trash    <page-id> [--commit]             trash a page (marker-guarded; close-out)
  notion-payload check    <page-id> <match> [--uncheck] [--commit]   toggle one checklist box
  notion-payload append   <page-id> [md-file|-] [--commit]           append blocks to a page body
  notion-payload comment  <page-id> <text|-> [--commit]              post a comment (e.g. review findings)
  notion-payload schema   [db] [--live]                    embedded schema, or --live drift vs Notion
  notion-payload hints    <db> [type]                      section questionnaire (rules + 禁-lists)
  notion-payload template <db> [type]                      skeleton body to fill in (shape + I3/I4)
  notion-payload sections <db> [type]                      key::heading-regex, one per line (for scripts)
  notion-payload criteria <db>                             criteria→sections routing table
  notion-payload --help

DBs: ${Object.keys(DB).join(', ')}
Plan body schemas: schemas/product-plan.mjs (by Type), schemas/engineering-plan.mjs
Criteria registry: schemas/criteria.mjs

create/update without --commit print the plan only (no writes). --commit drives ntn:
  create → ntn api v1/pages (POST props) + ntn pages edit (Markdown body) + verify, per row.
  update → ntn api v1/pages/<id> (PATCH properties only), per row.
Reads: build the filter here, then \`ntn datasources query <ds> --filter '<json>' --json\`.

Manifest (create): { "db": "feature-archive", "rows": [ { …props + body sections } ] }
Manifest (update): { "db": "tasklist", "rows": [ { "page_id": "…", "Stage": "Review" } ] }

bodyFile — author the body ONCE in a Markdown file, upload it byte-exact (never
re-typed into the manifest → CJK-safe). Put "bodyFile": "<path>" on a row instead
of inline body sections / "content"; its "## Heading"s must match the DB schema.
On UPDATE, a bodyFile does a safe full-body replace (the file is the SoT); without
it, update stays properties-only. Convention: docs/session-journal/<sid>/<artifact>.md.
  create: { "db":"engineering-plan", "rows":[ { "Name":"…", "Task":"…", "bodyFile":"docs/session-journal/<sid>/engineering-plan.md" } ] }
Use "-" to read the manifest from stdin.`;

// ── Project KB resolution ───────────────────────────────────────────────────────
//
// The registry above carries STRUCTURE — property names, types, body skeletons,
// and the workflow's own vocabularies (Status, Stage). Those are the plan
// cycle's contract and are identical in every project.
//
// Two things are NOT: which Notion data sources to write to, and the feature
// taxonomy (Area / Feature Area), which mirrors each project's own modules.
// Both are resolved here at startup from ONE input — the KB root page id — so a
// project configures a single value instead of eight ids that can silently rot.
//
// FAIL CLOSED. A missing or wrong root must abort, never fall back to a default.
// The failure this guards against is not a harmless error: a baked-in default
// would write one project's plans into another project's workspace. Databases
// absent under the root are DELETED from the registry rather than left with a
// null id, so the existing `unknown db "x". Valid: …` error names exactly the
// databases this project actually has.
//
// "Absent" and "titled differently" look identical from here, and only one of
// them is a legitimate state. `unknownDb` below tells them apart in the error
// text so a mistitled database is never mistaken for one the project chose not
// to keep.

const DB_TITLE = {
  'feature-archive': 'Feature Archive',
  'decision-log': 'Decision Log',
  'tasklist': 'TaskList',
  'product-plan': 'Product Plan',
  'engineering-plan': 'Engineering Plan',
  'release-log': 'Release Log',
  'analytics-catalog': 'Analytics Event Catalog',
};

// A project may title its databases in its own language. Those titles are the
// project's, not the workflow's, so they are read from an optional file rather
// than baked in here — the same split as `.claude/pm-vocabulary.txt`.
//
//   .claude/kb-databases.txt
//   <registry-key> = <exact Notion database title>
//
// Blank lines and #-comments ignored. Absent file → the English titles above.
const DB_TITLE_OVERRIDE_FILE = '.claude/kb-databases.txt';

function loadTitleOverrides() {
  const path = `${process.env.CLAUDE_PROJECT_DIR || '.'}/${DB_TITLE_OVERRIDE_FILE}`;
  let text;
  try { text = readFileSync(path, 'utf8'); } catch { return; }
  for (const line of text.split('\n')) {
    const s = line.trim();
    if (!s || s.startsWith('#')) continue;
    const i = s.indexOf('=');
    if (i < 1) fail(`${DB_TITLE_OVERRIDE_FILE}: bad line "${s}", expected <key> = <title>`);
    const key = s.slice(0, i).trim();
    const title = s.slice(i + 1).trim();
    if (!(key in DB_TITLE)) {
      fail(`${DB_TITLE_OVERRIDE_FILE}: unknown key "${key}". `
        + `Valid: ${Object.keys(DB_TITLE).join(', ')}`);
    }
    if (!title) fail(`${DB_TITLE_OVERRIDE_FILE}: "${key}" has an empty title`);
    DB_TITLE[key] = title;
  }
}

// Registry keys dropped during resolution because no child database carried
// their title. Kept so `unknownDb` can say WHY the key is gone.
const MISSING_DB = new Map();

// Every "unknown db" error routes through here. A key the plugin does not have
// is a typo; a key it has but this workspace did not yield is a title mismatch,
// and the fix is a line in the override file — not a different command.
function unknownDb(key) {
  const valid = `Valid: ${Object.keys(DB).join(', ')}`;
  const wantedTitle = MISSING_DB.get(key);
  if (!wantedTitle) return `unknown db "${key}". ${valid}`;
  return `unknown db "${key}". ${valid}\n\n`
    + `  "${key}" IS a database this plugin knows, but no child database titled\n`
    + `  "${wantedTitle}" exists under the KB root. Either this project does not\n`
    + `  keep that database, or it titles it differently — if the latter, map it:\n\n`
    + `    ${DB_TITLE_OVERRIDE_FILE}\n`
    + `    ${key} = <the exact title in Notion>`;
}

// Property names whose option list belongs to the project, not the workflow.
// Everything else keeps the registry's static vocabulary so a typo fails fast,
// locally, before any network call.
const PROJECT_VOCAB = new Set(['Area', 'Feature Area', 'Feature']);

function resolveRegistry(rootId) {
  if (!rootId) {
    fail('no KB root page id. Pass --root <page-id> (the project states it in '
      + 'its CLAUDE.md). Refusing to guess: a default root would write this '
      + "project's plans into another project's Notion workspace.");
  }
  loadTitleOverrides();

  // Child databases of the root page, by title.
  let children;
  try {
    children = JSON.parse(ntn(['api', `v1/blocks/${rootId}/children`]));
  } catch (e) {
    fail(`could not read KB root ${rootId}: ${e.message}`);
  }
  if (children?.object === 'error') {
    fail(`could not read KB root ${rootId}: ${children.code} — ${children.message}`);
  }

  const byTitle = new Map();
  for (const b of children.results || []) {
    if (b.type !== 'child_database') continue;
    byTitle.set((b.child_database?.title || '').trim(), b.id);
  }
  if (byTitle.size === 0) {
    fail(`KB root ${rootId} has no child databases — wrong page, or the `
      + 'integration lacks access to it.');
  }

  const resolvedDs = {};
  for (const key of Object.keys(DB)) {
    const dbId = byTitle.get(DB_TITLE[key]);
    if (!dbId) { MISSING_DB.set(key, DB_TITLE[key]); delete DB[key]; continue; }
    // `resolve` prints TSV unless asked for JSON.
    const res = JSON.parse(ntn(['datasources', 'resolve', dbId, '--json']));
    const dsId = res.data_sources?.[0]?.id;
    if (!dsId) fail(`"${DB_TITLE[key]}" resolved to no data source (db ${dbId}).`);
    DB[key].ds = dsId;
    resolvedDs[key] = dsId;
  }

  // Late-bind relation targets now that every ds id is known, and adopt the
  // live option list for the project-owned taxonomies.
  for (const [key, def] of Object.entries(DB)) {
    for (const [propName, spec] of Object.entries(def.props || {})) {
      if (spec.dsRef) {
        const target = resolvedDs[spec.dsRef];
        if (!target) {
          fail(`${key}.${propName} relates to "${DB_TITLE[spec.dsRef]}", which is `
            + `absent under the KB root — the relation cannot be written.`);
        }
        spec.ds = target;
      }
      if (PROJECT_VOCAB.has(propName) && spec.options) {
        const live = JSON.parse(ntn(['api', `v1/data_sources/${def.ds}`]));
        const p = live.properties?.[propName];
        const opts = p?.multi_select?.options ?? p?.select?.options;
        if (opts) spec.options = opts.map((o) => o.name);
      }
    }
  }
}

// ── CLI ─────────────────────────────────────────────────────────────────────────
function readInput(arg) {
  if (arg === '-' || arg === undefined) return readFileSync(0, 'utf8');
  return readFileSync(arg, 'utf8');
}

function main() {
  const argv = process.argv.slice(2);
  const cmd = argv[0];
  const flags = new Set(argv.filter((a) => a.startsWith('--')));
  const pos = argv.slice(1).filter((a) => !a.startsWith('--'));

  if (!cmd || cmd === '--help' || cmd === '-h') { console.log(HELP); return; }

  // `--root <page-id>` is consumed here, before the positional split below would
  // mistake the id for a manifest path.
  const rootIdx = argv.indexOf('--root');
  const rootId = rootIdx === -1 ? undefined : argv[rootIdx + 1];
  if (rootId) { pos.splice(pos.indexOf(rootId), 1); }

  // Resolve the project's KB only for the commands that actually need a data
  // source id or the project-owned vocabulary. Resolution costs one API call
  // plus one per database — several seconds, and it needs the network.
  //
  // The structural commands (`hints`, `criteria`) need neither: they print
  // section skeletons and grading criteria straight out of schemas/, and a
  // planning cycle calls them repeatedly. Making them pay for the workspace
  // they never touch bought nothing and made an offline `hints` impossible.
  // The page-id commands (`trash` / `check` / `append` / `comment`) address a
  // page directly and never consult the registry at all.
  //
  // Consequence to know: an unresolved registry lists the plugin's full set of
  // databases, not the project's subset, so `hints`/`criteria` will answer for
  // a database this workspace does not keep. That is correct — they are asking
  // about the SCHEMA, not about the workspace.
  const NEEDS_KB = new Set(['create', 'update', 'set', 'filter']);
  // `schema` is the discovery command: keep it usable offline, but resolve when
  // the caller supplied a root (then it reports real ds ids + live vocabulary).
  if (NEEDS_KB.has(cmd) || (cmd === 'schema' && (flags.has('--live') || rootId))) {
    try {
      resolveRegistry(rootId);
    } catch (e) {
      if (e instanceof BuildError) { console.error(`✗ ${e.message}`); process.exitCode = 1; return; }
      throw e;
    }
  }

  if (cmd === 'schema') { if (flags.has('--live')) schemaLive(pos[0]); else printSchema(pos[0]); return; }
  if (cmd === 'hints') { printHints(pos[0], pos[1]); return; }
  if (cmd === 'sections') { printSections(pos[0], pos[1]); return; }
  if (cmd === 'template') { printTemplate(pos[0], pos[1]); return; }
  if (cmd === 'criteria') { printCriteria(pos[0]); return; }
  if (cmd === 'filter') {
    try { printFilter(pos[0], pos.slice(1), flags.has('--json')); }
    catch (e) { if (e instanceof BuildError) { console.error(`✗ ${e.message}`); process.exitCode = 1; } else throw e; }
    return;
  }
  if (cmd === 'trash') {
    if (!pos[0]) { console.error('trash requires a <page-id>'); process.exitCode = 1; return; }
    try { trashPage(pos[0], flags.has('--commit')); }
    catch (e) { if (e instanceof BuildError) { console.error(`✗ ${e.message}`); process.exitCode = 1; } else throw e; }
    return;
  }
  if (cmd === 'check') {
    if (!pos[0] || !pos[1]) { console.error('check requires <page-id> <match-text>'); process.exitCode = 1; return; }
    try { checkBox(pos[0], pos.slice(1).join(' '), flags.has('--uncheck'), flags.has('--commit')); }
    catch (e) { if (e instanceof BuildError) { console.error(`✗ ${e.message}`); process.exitCode = 1; } else throw e; }
    return;
  }
  if (cmd === 'append') {
    if (!pos[0]) { console.error('append requires <page-id> [md-file|-]'); process.exitCode = 1; return; }
    try { appendBlocks(pos[0], mdToBlocks(readInput(pos[1])), flags.has('--commit')); }
    catch (e) { if (e instanceof BuildError) { console.error(`✗ ${e.message}`); process.exitCode = 1; } else throw e; }
    return;
  }
  if (cmd === 'comment') {
    if (!pos[0]) { console.error('comment requires <page-id> and text (inline, or "-" for stdin)'); process.exitCode = 1; return; }
    const text = (pos[1] === '-' || pos[1] === undefined) ? readInput('-') : pos.slice(1).join(' ');
    try { postComment(pos[0], text, flags.has('--commit')); }
    catch (e) { if (e instanceof BuildError) { console.error(`✗ ${e.message}`); process.exitCode = 1; } else throw e; }
    return;
  }
  if (cmd === 'set') {
    // One-row property update without a manifest file — the common Status/Stage
    // flip. Synthesizes an update manifest and reuses build()+commitUpdate(), so
    // vocabulary validation is byte-identical to `update`.
    if (pos.length < 3) { console.error('set requires <db> <page-id> Prop=Val […]'); process.exitCode = 1; return; }
    try {
      const def = DB[pos[0]];
      if (!def) fail(unknownDb(pos[0]));
      const row = { page_id: pos[1] };
      for (const p of pos.slice(2)) {
        const i = p.indexOf('=');
        if (i < 1) fail(`bad clause "${p}", expected Prop=Val`);
        const name = p.slice(0, i);
        const raw = p.slice(i + 1);
        const spec = def.props[name];
        if (!spec) fail(`${pos[0]}: unknown property "${name}". Known: ${Object.keys(def.props).join(', ')}`);
        // CLI args arrive as strings — coerce the two non-string property shapes
        // (multi_select comma-splits; checkbox parses true/1). Everything else
        // passes through for encodeProp's own validation.
        row[name] = spec.type === 'multi_select' ? raw.split(',').map((s) => s.trim()).filter(Boolean)
          : spec.type === 'checkbox' ? raw === 'true' || raw === '1'
          : raw;
      }
      const { dbKey, rows } = build({ db: pos[0], rows: [row] }, 'update');
      if (!flags.has('--commit')) { console.log(JSON.stringify(rows, null, 2)); return; }
      commitUpdate(dbKey, rows);
    } catch (e) {
      if (e instanceof BuildError) { console.error(`✗ ${e.message}`); process.exitCode = 1; }
      else throw e;
    }
    return;
  }
  if (cmd !== 'create' && cmd !== 'update') {
    console.error(`unknown command "${cmd}".\n\n${HELP}`); process.exitCode = 1; return;
  }

  const commit = flags.has('--commit');
  let manifest;
  try { manifest = JSON.parse(readInput(pos[0])); }
  catch (e) { console.error(`could not parse manifest JSON: ${e.message}`); process.exitCode = 1; return; }

  try {
    const { dbKey, rows } = build(manifest, cmd);
    if (!commit) { console.log(JSON.stringify(rows, null, 2)); return; }
    if (cmd === 'create') commitCreate(dbKey, rows);
    else commitUpdate(dbKey, rows);
  } catch (e) {
    if (e instanceof BuildError) { console.error(`✗ ${e.message}`); process.exitCode = 1; }
    else throw e;
  }
}

main();
