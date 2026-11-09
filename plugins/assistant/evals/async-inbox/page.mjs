#!/usr/bin/env node
// Runs the Inbox page's <script> against a minimal DOM and a fake `window.claude`, and prints
// one `<id>-<what>=0|1` line per behaviour a user sees. Plain node, no dependencies.
// Usage: node page.mjs <inbox.html>
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const VOID_TAGS = new Set(['meta', 'input', 'br', 'img', 'hr', 'link', 'source']);
const BOOL_PROPS = ['hidden', 'disabled'];
const STRING_PROPS = { id: 'id', className: 'class', type: 'type', name: 'name', href: 'href', target: 'target',
  rel: 'rel', title: 'title', placeholder: 'placeholder', htmlFor: 'for', role: 'role' };

class TextNode {
  constructor(data) { this.data = String(data); this.parentNode = null; this.nodeType = 3; }
  get textContent() { return this.data; }
  set textContent(v) { this.data = String(v); }
  remove() { if (this.parentNode) this.parentNode.removeChild(this); }
}

class ElementNode {
  constructor(tag, doc) {
    this.tagName = tag.toUpperCase(); this.nodeType = 1; this.ownerDocument = doc;
    this.childNodes = []; this.parentNode = null; this.attrs = new Map(); this.listeners = {};
    this.style = { setProperty() {}, removeProperty() {} };
    this.valueProp = undefined; this.checked = false;
    this.dataset = new Proxy({}, {
      get: (_, k) => this.attrs.get('data-' + kebab(k)),
      set: (_, k, v) => { this.attrs.set('data-' + kebab(k), String(v)); return true; },
      deleteProperty: (_, k) => { this.attrs.delete('data-' + kebab(k)); return true; },
      has: (_, k) => this.attrs.has('data-' + kebab(k)),
    });
  }
  get children() { return this.childNodes.filter((n) => n.nodeType === 1); }
  get firstChild() { return this.childNodes[0] ?? null; }
  get lastChild() { return this.childNodes.at(-1) ?? null; }
  get firstElementChild() { return this.children[0] ?? null; }
  get parentElement() { return this.parentNode && this.parentNode.nodeType === 1 ? this.parentNode : null; }
  get nextElementSibling() { const s = this.parentNode?.children ?? []; return s[s.indexOf(this) + 1] ?? null; }
  get textContent() { return this.childNodes.map((n) => n.textContent).join(''); }
  set textContent(v) { this.childNodes.forEach((n) => { n.parentNode = null; }); this.childNodes = []; if (v !== '' && v != null) this.append(String(v)); }
  get innerText() { return this.textContent; }
  set innerText(v) { this.textContent = v; }
  set innerHTML(html) { this.textContent = ''; parseHtml(String(html), this, this.ownerDocument); }
  get innerHTML() { return this.textContent; }
  get value() { return this.valueProp ?? this.attrs.get('value') ?? (this.tagName === 'TEXTAREA' ? this.textContent : ''); }
  set value(v) { this.valueProp = String(v); }
  get classList() {
    const get = () => (this.attrs.get('class') || '').split(/\s+/).filter(Boolean);
    const put = (l) => this.attrs.set('class', l.join(' '));
    return {
      contains: (c) => get().includes(c),
      add: (...cs) => put([...new Set([...get(), ...cs])]),
      remove: (...cs) => put(get().filter((x) => !cs.includes(x))),
      toggle: (c, force) => { const on = force ?? !get().includes(c); if (on) put([...new Set([...get(), c])]); else put(get().filter((x) => x !== c)); return on; },
    };
  }
  getAttribute(k) { return this.attrs.has(k) ? this.attrs.get(k) : null; }
  setAttribute(k, v) { this.attrs.set(k, String(v)); if (k === 'value') this.valueProp = undefined; }
  removeAttribute(k) { this.attrs.delete(k); }
  hasAttribute(k) { return this.attrs.has(k); }
  toggleAttribute(k, force) { const on = force ?? !this.attrs.has(k); if (on) this.attrs.set(k, ''); else this.attrs.delete(k); return on; }
  adopt(n) { const node = typeof n === 'string' ? new TextNode(n) : n; if (node.parentNode) node.parentNode.removeChild(node); node.parentNode = this; return node; }
  append(...ns) { for (const n of ns) this.childNodes.push(this.adopt(n)); }
  appendChild(n) { this.append(n); return n; }
  prepend(...ns) { this.childNodes.unshift(...ns.map((n) => this.adopt(n))); }
  insertBefore(n, ref) { const node = this.adopt(n); const i = ref ? this.childNodes.indexOf(ref) : -1; if (i < 0) this.childNodes.push(node); else this.childNodes.splice(i, 0, node); return n; }
  replaceChildren(...ns) { this.textContent = ''; this.append(...ns); }
  removeChild(n) { this.childNodes = this.childNodes.filter((c) => c !== n); n.parentNode = null; return n; }
  remove() { if (this.parentNode) this.parentNode.removeChild(this); }
  replaceWith(...ns) { const p = this.parentNode; if (!p) return; const i = p.childNodes.indexOf(this); p.removeChild(this); p.childNodes.splice(i, 0, ...ns.map((n) => p.adopt(n))); }
  before(...ns) { const p = this.parentNode; const i = p.childNodes.indexOf(this); p.childNodes.splice(i, 0, ...ns.map((n) => p.adopt(n))); }
  after(...ns) { const p = this.parentNode; const i = p.childNodes.indexOf(this); p.childNodes.splice(i + 1, 0, ...ns.map((n) => p.adopt(n))); }
  contains(n) { for (let x = n; x; x = x.parentNode) if (x === this) return true; return false; }
  descendants() { return this.children.flatMap((c) => [c, ...c.descendants()]); }
  querySelectorAll(sel) { return this.descendants().filter((e) => matches(e, sel)); }
  querySelector(sel) { return this.querySelectorAll(sel)[0] ?? null; }
  matches(sel) { return matches(this, sel); }
  closest(sel) { for (let x = this; x && x.nodeType === 1; x = x.parentNode) if (matches(x, sel)) return x; return null; }
  addEventListener(type, fn) { (this.listeners[type] ||= []).push(fn); }
  removeEventListener(type, fn) { this.listeners[type] = (this.listeners[type] || []).filter((f) => f !== fn); }
  dispatchEvent(ev) {
    ev.target ??= this;
    for (let x = this; x && !ev.stopped; x = x.parentNode) {
      ev.currentTarget = x;
      for (const fn of [...(x.listeners?.[ev.type] || [])]) typeof fn === 'function' ? fn.call(x, ev) : fn.handleEvent(ev);
    }
    return !ev.defaultPrevented;
  }
  click() {
    if (this.disabled) return;
    const radio = this.tagName === 'INPUT' && this.type === 'radio';
    const box = this.tagName === 'INPUT' && this.type === 'checkbox';
    if (radio) {
      const root = this.closest('form') || this.ownerDocument.body;
      root.querySelectorAll('input').filter((i) => i.type === 'radio' && i.name === this.name).forEach((i) => { i.checked = false; });
      this.checked = true;
    }
    if (box) this.checked = !this.checked;
    const ok = this.dispatchEvent(makeEvent('click'));
    if (radio || box) { this.dispatchEvent(makeEvent('input')); this.dispatchEvent(makeEvent('change')); }
    const form = this.closest('form');
    if (ok && form && this.tagName === 'BUTTON' && (this.type || 'submit') === 'submit') form.dispatchEvent(makeEvent('submit'));
    if (ok && this.tagName === 'LABEL') { const i = this.querySelector('input'); if (i) i.click(); }
  }
  focus() {} blur() {} scrollIntoView() {} getBoundingClientRect() { return { top: 0, left: 0, width: 0, height: 0 }; }
}
for (const p of BOOL_PROPS) Object.defineProperty(ElementNode.prototype, p, {
  get() { return this.attrs.has(p); }, set(v) { if (v) this.attrs.set(p, ''); else this.attrs.delete(p); },
});
for (const [p, a] of Object.entries(STRING_PROPS)) Object.defineProperty(ElementNode.prototype, p, {
  get() { return this.attrs.get(a) ?? ''; }, set(v) { this.attrs.set(a, String(v)); },
});

function kebab(k) { return String(k).replace(/[A-Z]/g, (c) => '-' + c.toLowerCase()); }
function makeEvent(type, init = {}) {
  return { type, bubbles: true, ...init, defaultPrevented: false, stopped: false, target: null, currentTarget: null,
    preventDefault() { this.defaultPrevented = true; }, stopPropagation() { this.stopped = true; } };
}

// Compound selectors (tag, #id, .class, [attr], [attr="v"], :checked, :disabled) joined by
// descendant combinators, in comma groups.
function matches(el, sel) {
  return String(sel).split(',').some((group) => {
    const parts = group.trim().replace(/\s*>\s*/g, ' ').split(/\s+/);
    if (!matchCompound(el, parts.at(-1))) return false;
    let x = el.parentElement;
    for (let i = parts.length - 2; i >= 0; i--) {
      while (x && !matchCompound(x, parts[i])) x = x.parentElement;
      if (!x) return false;
      x = x.parentElement;
    }
    return true;
  });
}
function matchCompound(el, c) {
  const re = /^([a-zA-Z][\w-]*|\*)|#([\w-]+)|\.([\w-]+)|\[([\w-]+)(?:([~^$*]?=)["']?([^"'\]]*)["']?)?\]|:(checked|disabled|not\(([^)]*)\))/g;
  let m, used = 0;
  while ((m = re.exec(c))) {
    used += m[0].length;
    if (m[1] && m[1] !== '*' && el.tagName !== m[1].toUpperCase()) return false;
    if (m[2] && el.id !== m[2]) return false;
    if (m[3] && !el.classList.contains(m[3])) return false;
    if (m[4]) {
      if (!el.hasAttribute(m[4])) return false;
      const v = el.getAttribute(m[4]); const want = m[6];
      if (m[5] === '=' && v !== want) return false;
      if (m[5] === '^=' && !v.startsWith(want)) return false;
      if (m[5] === '~=' && !v.split(/\s+/).includes(want)) return false;
    }
    if (m[7] === 'checked' && !el.checked) return false;
    if (m[7] === 'disabled' && !el.disabled) return false;
    if (m[8] && matchCompound(el, m[8])) return false;
  }
  return used === c.length;
}

function parseHtml(html, root, doc) {
  const stack = [root];
  const tok = /<!--[\s\S]*?-->|<(script|style)\b[^>]*>[\s\S]*?<\/\1>|<(\/?)([a-zA-Z][\w-]*)((?:[^>"']|"[^"]*"|'[^']*')*)>|([^<]+)/g;
  let m;
  while ((m = tok.exec(html))) {
    const top = stack.at(-1);
    if (m[5]) { top.append(decode(m[5])); continue; }
    if (!m[3]) continue;
    const tag = m[3].toLowerCase();
    if (m[2]) { const i = stack.map((e) => e.tagName).lastIndexOf(tag.toUpperCase()); if (i > 0) stack.length = i; continue; }
    const el = doc.createElement(tag);
    for (const a of m[4].matchAll(/([^\s=/]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/g)) el.setAttribute(a[1], decode(a[2] ?? a[3] ?? a[4] ?? ''));
    top.append(el);
    if (!VOID_TAGS.has(tag) && !m[4].endsWith('/')) stack.push(el);
  }
}
function decode(s) {
  return s.replace(/&(amp|lt|gt|quot|#39|nbsp|rsquo|lsquo|hellip|middot);/g, (_, e) =>
    ({ amp: '&', lt: '<', gt: '>', quot: '"', '#39': "'", nbsp: ' ', rsquo: '’', lsquo: '‘', hellip: '…', middot: '·' })[e]);
}

function makeDocument(html) {
  const doc = { listeners: {}, nodeType: 9 };
  doc.createElement = (t) => new ElementNode(t, doc);
  doc.createTextNode = (t) => new TextNode(t);
  doc.createDocumentFragment = () => new ElementNode('#fragment', doc);
  const htmlEl = new ElementNode('html', doc); const head = new ElementNode('head', doc); const body = new ElementNode('body', doc);
  htmlEl.append(head, body); htmlEl.parentNode = doc;
  Object.assign(doc, { documentElement: htmlEl, head, body });
  for (const k of ['querySelector', 'querySelectorAll']) doc[k] = (s) => htmlEl[k](s);
  doc.getElementById = (id) => htmlEl.querySelector('#' + id);
  doc.addEventListener = (t, fn) => { (doc.listeners[t] ||= []).push(fn); };
  doc.removeEventListener = () => {};
  doc.readyState = 'complete';
  parseHtml(html.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, ''), body, doc);
  return doc;
}

// The fake `window.claude`: owner signed in, a session listening; `fail` picks which call rejects,
// `notOwner` makes the viewer someone else and `noDb` withholds the database.
function makeClaude(questions, fail) {
  const store = { questions: new Map(questions.map((q) => [q.id, q])), answers: new Map() };
  const subs = { questions: [], answers: [] };
  const wakes = [], writes = [];
  const err = (code) => Object.assign(new Error(code), { code });
  const snap = (name) => {
    const docs = [...store[name]].map(([id, d]) => ({ id, exists: true, data: () => structuredClone(d) }));
    return { docs, size: docs.length, empty: docs.length === 0, forEach: (f) => docs.forEach(f) };
  };
  const emit = (name) => subs[name].forEach(([ok, bad]) => (fail.answersRead && name === 'answers' ? bad?.(err('permission_denied')) : ok(snap(name))));
  const docRef = (name, id) => ({
    id,
    set: (data) => {
      writes.push({ name, id, data: structuredClone(data) });
      if (fail.save && name === 'answers') return Promise.reject(err('permission_denied'));
      store[name].set(id, structuredClone(data));
      return Promise.resolve();
    },
    get: () => Promise.resolve({ id, exists: store[name].has(id), data: () => store[name].get(id) }),
    delete: () => { store[name].delete(id); return Promise.resolve(); },
  });
  const collection = (name) => ({
    doc: (id) => docRef(name, id),
    get: () => (fail.answersRead && name === 'answers' ? Promise.reject(err('permission_denied')) : Promise.resolve(snap(name))),
    onSnapshot: (ok, bad) => { subs[name].push([ok, bad]); queueMicrotask(() => emit(name)); return () => {}; },
  });
  const db = { collection };
  const comments = {
    canSendToClaude: () => Promise.resolve('available'),
    anchorFor: (el) => Promise.resolve({ el }),
    sendToClaude: (arg) => {
      wakes.push(typeof arg === 'string' ? arg : String(arg?.text ?? ''));
      return fail.wake ? Promise.reject(err('no_session')) : Promise.resolve();
    },
    list: () => Promise.resolve([]), onChange: () => () => {},
  };
  const owner = !fail.notOwner;
  const user = { isOwner: () => Promise.resolve(owner), me: () => Promise.resolve({ isOwner: owner }), isAnonymous: false };
  const api = { use: (k) => Promise.resolve({ db: fail.noDb ? null : db, comments, user }[k] ?? null) };
  return { api, store, emit, wakes, writes };
}

async function settle() { for (let i = 0; i < 40; i++) await new Promise((r) => setImmediate(r)); }

async function load(html, script, questions, fail = {}) {
  const doc = makeDocument(html);
  const claude = makeClaude(questions, fail);
  const timers = {
    setTimeout: (f, ms, ...a) => setTimeout(f, ms, ...a).unref(), clearTimeout,
    setInterval: (f, ms, ...a) => setInterval(f, ms, ...a).unref(), clearInterval,
  };
  const win = {
    document: doc, claude: claude.api, console, URL, Promise, Date, Error, structuredClone, queueMicrotask, ...timers,
    navigator: { userAgent: 'node' }, location: { href: 'https://claude.ai/artifact/x' },
    matchMedia: () => ({ matches: false, addEventListener() {}, removeEventListener() {} }),
    requestAnimationFrame: (f) => setTimeout(f, 0).unref(), getComputedStyle: () => ({ getPropertyValue: () => '' }),
    localStorage: { getItem: () => null, setItem() {}, removeItem() {} }, addEventListener() {}, removeEventListener() {},
    Event: function Event(t, i) { return makeEvent(t, i); }, CustomEvent: function CustomEvent(t, i) { return makeEvent(t, i); },
  };
  win.window = win; win.self = win; win.globalThis = win;
  vm.runInContext(script, vm.createContext(win));
  await settle();
  return { doc, ...claude };
}

// What a user sees, read from the DOM without the page's class names: a card is the largest
// element that holds one question's text and no other's.
const visible = (el) => { for (let x = el; x && x.nodeType === 1; x = x.parentNode) if (x.hidden) return false; return true; };
const order = (doc) => doc.documentElement.descendants();
function cardOf(doc, q, all) {
  const others = all.filter((o) => o.id !== q.id).map((o) => o.question);
  let el = order(doc).filter((e) => e.textContent.trim() === q.question).at(-1);
  if (!el) return null;
  while (el.parentElement && !others.some((t) => el.parentElement.textContent.includes(t))) el = el.parentElement;
  return el;
}
const buttons = (root) => [root, ...root.descendants()].filter((e) => e.tagName === 'BUTTON' || (e.tagName === 'INPUT' && ['submit', 'button'].includes(e.type)));
const sendButtons = (doc) => buttons(doc.documentElement).filter((b) => visible(b) && /send/i.test(b.textContent + ' ' + b.value));
const inputs = (root) => root.descendants().filter((e) => ['INPUT', 'TEXTAREA', 'SELECT'].includes(e.tagName));
// Text after every card in document order and outside them: the bottom bar.
function bottomText(doc, cards) {
  const els = order(doc);
  const last = Math.max(...cards.map((c) => els.indexOf(c.descendants().at(-1) ?? c)));
  return els.slice(last + 1).filter((e) => visible(e) && !cards.some((c) => c.contains(e)))
    .flatMap((e) => e.childNodes.filter((n) => n.nodeType === 3).map((n) => n.data)).join(' ');
}
function choose(card, key, label) {
  const radio = inputs(card).find((i) => i.tagName === 'INPUT' && i.value === key);
  if (radio) return radio.click();
  const hit = card.descendants().find((e) => e.dataset.key === key) || card.descendants().filter((e) => e.textContent.trim() === label).at(-1);
  hit?.click();
}
function type(card, text) {
  const ta = card.descendants().find((e) => e.tagName === 'TEXTAREA');
  if (!ta) return;
  ta.value = text; ta.dispatchEvent(makeEvent('input')); ta.dispatchEvent(makeEvent('change'));
}

const QUESTIONS = [
  { id: 'q1', project: 'demo', task: 'alpha', question: 'Ship the beta to testers?', context: 'Two screens changed.', asked: '2026-11-01T09:00:00Z',
    options: [{ key: 'yes', label: 'Ship it', detail: 'Today' }, { key: 'no', label: 'Hold it', detail: 'Wait a week' }], link: 'https://example.com/review' },
  { id: 'q2', project: 'demo', task: 'beta', question: 'What should the empty state say?', asked: '2026-11-01T09:01:00Z', options: [], link: 'http://example.com/plain' },
  { id: 'q3', project: 'demo', task: 'gamma', question: 'Keep the old export format?', asked: '2026-11-01T09:02:00Z',
    options: [{ key: 'keep', label: 'Keep' }, { key: 'drop', label: 'Drop' }], link: 'javascript:alert(1)' },
  { id: 'q4', project: 'demo', task: 'delta', question: 'Merging the release PR next.', kind: 'notice', asked: '2026-11-01T09:03:00Z' },
];
const NOTE = 'Say there is nothing here yet';

// A card still holds what the user filled in: the chosen option checked, the typed note in its field.
const keeps = (card, key, note) => {
  const radio = key && inputs(card).find((i) => i.tagName === 'INPUT' && i.value === key);
  const ta = note && card.descendants().find((e) => e.tagName === 'TEXTAREA');
  return (!key || (radio && radio.checked)) && (!note || (ta && ta.value === note));
};
const pageText = (doc) => order(doc).filter(visible).flatMap((e) => e.childNodes.filter((n) => n.nodeType === 3).map((n) => n.data)).join(' ');

const out = {};
const say = (k, v) => { out[k] = v ? 1 : 0; };
const KEYS = ['s18-db', 's18-notice-no-button', 's18-notice-no-input', 's18-save-fail-note', 's18-save-fail-resend', 's18-answers-fail-no-send',
  's18-link-https', 's18-link-not-https', 's19-textarea-every-card', 's19-text-only-answer', 's20-one-send', 's20-send-at-bottom',
  's20-one-wake-both-ids', 's20-note-not-in-comment', 's21-wake-fail-bar', 's21-wake-fail-after-render', 's22-proto-id-unanswered', 's22-proto-id-note-saved',
  's23-draft-kept-rerender', 's23-draft-kept-save-fail', 's24-not-owner-no-send', 's24-no-db-pill', 's24-no-db-no-card',
  's24-bad-id-not-sent', 's24-bad-id-says-so'];
const errors = [];
process.on('unhandledRejection', (e) => errors.push(String(e?.message ?? e)));

async function main() {
  const html = readFileSync(process.argv[2], 'utf8');
  const script = [...html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)].map((m) => m[1]).join('\n;\n');
  const qs = QUESTIONS.slice(0, 3); const notice = QUESTIONS[3];

  // A full page: what renders, and one send of two answered questions.
  {
    const { doc, store, wakes } = await load(html, script, QUESTIONS);
    const cards = QUESTIONS.map((q) => cardOf(doc, q, QUESTIONS));
    const [c1, c2, c3, c4] = cards;
    say('s19-textarea-every-card', cards.slice(0, 3).every((c) => c && c.descendants().filter((e) => e.tagName === 'TEXTAREA').length === 1));
    say('s18-notice-no-button', c4 && buttons(c4).length === 0);
    say('s18-notice-no-input', c4 && inputs(c4).length === 0);
    const links = doc.documentElement.descendants().filter((e) => e.tagName === 'A');
    say('s18-link-https', c1 && c1.descendants().some((a) => a.tagName === 'A' && a.href === 'https://example.com/review'));
    say('s18-link-not-https', c2 && c3 && links.every((a) => a.href.startsWith('https:') || !a.href) && !c2.descendants().some((a) => a.tagName === 'A' && a.href));
    const sends = sendButtons(doc);
    say('s20-one-send', sends.length === 1 && cards.every((c) => c && !c.contains(sends[0])));
    const els = order(doc);
    say('s20-send-at-bottom', sends.length === 1 && cards.every((c) => c && els.indexOf(sends[0]) > els.indexOf(c.descendants().at(-1) ?? c)));
    if (c1 && c2) { choose(c1, 'yes', 'Ship it'); type(c2, NOTE); }
    await settle();
    sends[0]?.click();
    await settle();
    const a1 = store.answers.get('q1'), a2 = store.answers.get('q2');
    say('s18-db', a1?.choice === 'yes' && a2?.note === NOTE && !store.answers.has('q3'));
    say('s19-text-only-answer', a2?.note === NOTE && wakes.some((w) => /\bq2\b/.test(w)));
    say('s20-one-wake-both-ids', wakes.length === 1 && /\bq1\b/.test(wakes[0]) && /\bq2\b/.test(wakes[0]) && !/\bq3\b/.test(wakes[0]));
    say('s20-note-not-in-comment', wakes.length > 0 && wakes.every((w) => !w.includes(NOTE)));
    say('s18-answers-fail-no-send', sends.length > 0 && (await (async () => {
      const r = await load(html, script, qs, { answersRead: true });
      return sendButtons(r.doc).length === 0;
    })()));
  }

  // A new question arrives while answers are half filled in: the rebuilt cards keep them.
  {
    const extra = { id: 'q5', project: 'demo', task: 'epsilon', question: 'Rename the project?', asked: '2026-11-01T09:04:00Z', options: [] };
    const { doc, store, emit } = await load(html, script, qs);
    const c1 = cardOf(doc, qs[0], qs), c2 = cardOf(doc, qs[1], qs);
    if (c1 && c2) { choose(c1, 'yes', 'Ship it'); type(c2, NOTE); }
    await settle();
    store.questions.set(extra.id, extra);
    emit('questions');
    await settle();
    const all = [...qs, extra];
    const n1 = cardOf(doc, qs[0], all), n2 = cardOf(doc, qs[1], all);
    say('s23-draft-kept-rerender', !!(c1 && c2 && n1 && n2 && keeps(n1, 'yes') && keeps(n2, '', NOTE) && cardOf(doc, extra, all)));
  }

  // The answer is saved, but no session is woken: the reason stays in the bottom bar.
  {
    const { doc, emit } = await load(html, script, QUESTIONS, { wake: true });
    const reason = /no_session|no session/i;
    const cardsNow = () => QUESTIONS.map((q) => cardOf(doc, q, QUESTIONS)).filter(Boolean);
    const c1 = cardOf(doc, QUESTIONS[0], QUESTIONS);
    if (c1) choose(c1, 'yes', 'Ship it');
    await settle();
    const before = reason.test(bottomText(doc, cardsNow()));
    sendButtons(doc)[0]?.click();
    await settle();
    say('s21-wake-fail-bar', !before && reason.test(bottomText(doc, cardsNow())));
    emit('answers'); emit('questions');
    await settle();
    say('s21-wake-fail-after-render', !before && reason.test(bottomText(doc, cardsNow())));
  }

  // Saving fails: the user is told, and can press send again.
  {
    const { doc, emit } = await load(html, script, qs, { save: true });
    const c1 = cardOf(doc, qs[0], qs), c2 = cardOf(doc, qs[1], qs);
    if (c1) choose(c1, 'yes', 'Ship it');
    if (c2) type(c2, NOTE);
    await settle();
    const text = () => order(doc).filter(visible).flatMap((e) => e.childNodes.filter((n) => n.nodeType === 3).map((n) => n.data)).join(' ');
    const said = /permission_denied|sav(e|ing)[^.]{0,40}fail|fail[^.]{0,40}sav/i;
    const before = said.test(text());
    sendButtons(doc)[0]?.click();
    await settle();
    say('s18-save-fail-note', !before && said.test(text()));
    const again = sendButtons(doc);
    say('s18-save-fail-resend', again.length > 0 && again.every((b) => !b.disabled));
    const kept = () => { const n1 = cardOf(doc, qs[0], qs), n2 = cardOf(doc, qs[1], qs); return !!(n1 && n2 && keeps(n1, 'yes') && keeps(n2, '', NOTE)); };
    const keptNow = kept();
    emit('answers'); emit('questions');
    await settle();
    say('s23-draft-kept-save-fail', keptNow && kept());
  }

  // Ids that name Object.prototype members are ordinary ids: unanswered, and their typed note is saved.
  {
    const protoQs = ['constructor', 'toString'].map((id, i) => ({ id, project: 'demo', task: 'proto', question: 'Question filed under ' + id + '?', asked: '2026-11-02T09:0' + i + ':00Z', options: [] }));
    const { doc, store, wakes } = await load(html, script, protoQs);
    const cards = protoQs.map((q) => cardOf(doc, q, protoQs));
    say('s22-proto-id-unanswered', cards.every((c) => c && !/answered/i.test(c.textContent) && c.descendants().filter((e) => e.tagName === 'TEXTAREA').length === 1));
    cards.forEach((c, i) => c && type(c, 'note ' + protoQs[i].id));
    await settle();
    sendButtons(doc)[0]?.click();
    await settle();
    say('s22-proto-id-note-saved', protoQs.every((q) => store.answers.get(q.id)?.note === 'note ' + q.id) && wakes.length === 1);
  }

  // A viewer who isn't the owner can't answer: no Send button, every field disabled.
  {
    const { doc } = await load(html, script, qs, { notOwner: true });
    const cards = qs.map((q) => cardOf(doc, q, qs));
    const fields = cards.flatMap((c) => (c ? inputs(c) : []));
    say('s24-not-owner-no-send', cards.every(Boolean) && fields.length > 0 && fields.every((i) => i.disabled) && sendButtons(doc).length === 0);
  }

  // No database: the page says it can't connect, and shows no question to answer.
  {
    const { doc } = await load(html, script, qs, { noDb: true });
    const text = pageText(doc);
    say('s24-no-db-pill', /can.?t connect/i.test(text));
    say('s24-no-db-no-card', qs.every((q) => !text.includes(q.question)) && sendButtons(doc).length === 0);
  }

  // An id outside [A-Za-z0-9_-]{1,64} can't be answered: nothing is written or sent, and the bar says so.
  {
    const odd = { id: 'a.b', project: 'demo', task: 'odd', question: 'Question filed under a dot?', asked: '2026-11-02T09:00:00Z', options: [] };
    const { doc, store, wakes, writes } = await load(html, script, [odd]);
    const c = cardOf(doc, odd, [odd]);
    if (c) type(c, 'note for a dot');
    await settle();
    const btn = sendButtons(doc)[0];
    if (btn && !btn.disabled) btn.click();
    await settle();
    say('s24-bad-id-not-sent', !!c && wakes.length === 0 && writes.every((w) => w.id !== odd.id) && !store.answers.has(odd.id));
    say('s24-bad-id-says-so', /nothing was sent/i.test(pageText(doc)));
  }
}

try { await main(); } catch (e) { errors.push(String(e?.stack ?? e)); }
for (const k of KEYS) console.log(`${k}=${out[k] ?? 0}`);
for (const e of errors) console.error(`page-error: ${e}`);
process.exit(0);
