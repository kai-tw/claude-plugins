#!/usr/bin/env node
// asst-screens — build the ② screens page: one web page showing every rendered
// screenshot as its own image, at its original resolution. The images are
// embedded byte for byte (no re-encoding, no stitching), so nothing is scaled
// down before the founder sees it, and the page is one file the assistant
// publishes as an Artifact.
//
// Usage: asst-screens <task-slug> <image-dir>   → prints the page's path
//
// Images: .png .jpg .jpeg .webp .gif in <image-dir>. A name is split into
// screen, state, theme and locale:
// - `<screen>__<state…>__[<theme>__]<locale>` (e.g.
//   `step_wait__compact__starting__dark__zh-TW.png`): the first segment is the
//   screen, a last segment that is a BCP 47 tag is the locale, a `light` or
//   `dark` segment is the theme, and the segments between make up the state.
// - `<screen>-<state>[-<theme>][-<locale>]` (e.g. `sign-in-empty-zh-TW.png`):
//   the state is the last of empty · loading · error · populated in the name,
//   what comes before it is the screen and what comes after is the locale, so
//   either may hold a dash. Any other state name works too: the locale is then
//   the longest tail that is a BCP 47 tag (`zh-TW`, `zh-Hant`, `ja`), the state
//   the segment before it (or before the theme), and with no such tail the last
//   segment is the state. A name with a single segment is a screen with no state.
//
// labels.json in <image-dir> (optional) gives the page in the founder's
// language: {"lang": "zh-Hant", "title": "…", "summary": "…",
// "screens": {"<screen>": "…"}, "states": {"<state>": "…"}}. Without it the
// page shows the keys, in English.
//
// The page has one section per screen, headed by its label and its number of
// states; states in the order empty · loading · error · populated (any other
// state sorts by file name). Every image gets a number, so the founder can answer
// "which cell" with one, and its caption gives the state's label (with the theme
// and locale when there is more than one) above the file name. Cells are phone-width (at least 220px), so a portrait screenshot is never
// stretched to the page's width. A sticky bar shows one locale at a time (the
// first, until the founder picks another), one theme (light first) and one
// screen or all of them; numbers don't change when a filter hides a cell.
//
// The page lands at <root>/.claude/.assistant/tasks/<slug>/screens.html and is
// overwritten on each run. Exit: 0 = written, 1 = no images, 2 = usage or a
// labels.json that isn't valid JSON.

import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { dirname, extname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const MIME = { '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp', '.gif': 'image/gif' };
const STATES = ['empty', 'loading', 'error', 'populated'];
const THEMES = ['light', 'dark'];
const LOCALE = /^[a-z]{2,3}(-[A-Za-z]{4})?(-([A-Z]{2}|\d{3}))?$/;

// The page's own words, by labels.json's `lang`.
const UI = {
  en: { filter: 'Filter', screens: 'All screens', locales: 'All locales', themes: 'Both themes', light: 'Light', dark: 'Dark',
    count: (n) => ` (${n})`, summary: (i, s) => `${i} images · ${s} screens · click an image for full size (← → to step, Esc to close)` },
  'zh-Hant': { filter: '篩選', screens: '全部畫面', locales: '全部語言', themes: '淺色與深色', light: '淺色', dark: '深色',
    count: (n) => `（${n}）`, summary: (i, s) => `${s} 個畫面，共 ${i} 張圖。點圖看原尺寸（← → 切換，Esc 關閉）。` },
  'zh-Hans': { filter: '筛选', screens: '全部画面', locales: '全部语言', themes: '浅色与深色', light: '浅色', dark: '深色',
    count: (n) => `（${n}）`, summary: (i, s) => `${s} 个画面，共 ${i} 张图。点图看原尺寸（← → 切换，Esc 关闭）。` },
  ja: { filter: '絞り込み', screens: 'すべての画面', locales: 'すべての言語', themes: 'ライトとダーク', light: 'ライト', dark: 'ダーク',
    count: (n) => `（${n}）`, summary: (i, s) => `${s} 画面・${i} 枚。画像をクリックで原寸表示（← → で切り替え、Esc で閉じる）。` },
};

const [slug, imageDir] = process.argv.slice(2);
if (!slug || !imageDir || process.argv.length > 4) {
  console.error('Usage: asst-screens <task-slug> <image-dir>');
  process.exit(2);
}
const src = resolve(imageDir);
if (!existsSync(src) || !statSync(src).isDirectory()) {
  console.error(`asst-screens: no directory at ${src}`);
  process.exit(2);
}

let labels = {};
if (existsSync(join(src, 'labels.json'))) {
  try {
    labels = JSON.parse(readFileSync(join(src, 'labels.json'), 'utf8'));
  } catch (e) {
    console.error(`asst-screens: ${join(src, 'labels.json')} is not valid JSON: ${e.message}`);
    process.exit(2);
  }
}
const lang = labels.lang || 'en';
const ui = UI[lang] ?? UI[lang.split('-')[0]] ?? UI.en;
const screenLabel = (s) => labels.screens?.[s] ?? s;
const stateLabel = (s) => labels.states?.[s] ?? s.split('__').join(' · ');
let languageName = (l) => l;
try {
  const names = new Intl.DisplayNames([lang], { type: 'language' });
  languageName = (l) => { try { return names.of(l); } catch { return l; } };
} catch {}

// Pixel size from the file header, so the caption shows what was rendered.
function size(buf, ext) {
  if (ext === '.png' && buf.length >= 24) return [buf.readUInt32BE(16), buf.readUInt32BE(20)];
  if (ext === '.gif' && buf.length >= 10) return [buf.readUInt16LE(6), buf.readUInt16LE(8)];
  if (ext === '.jpg' || ext === '.jpeg') {
    for (let i = 2; i + 9 < buf.length; ) {
      if (buf[i] !== 0xff) return null;
      const marker = buf[i + 1];
      if (marker >= 0xc0 && marker <= 0xcf && ![0xc4, 0xc8, 0xcc].includes(marker))
        return [buf.readUInt16BE(i + 7), buf.readUInt16BE(i + 5)];
      i += 2 + buf.readUInt16BE(i + 2);
    }
  }
  return null;
}

// `__` separates the parts; a single `-` may sit inside a screen or a locale.
function underscored(name) {
  const segs = name.split('__');
  const locale = segs.length > 1 && LOCALE.test(segs.at(-1)) ? segs.pop() : '';
  const t = segs.findIndex((s, i) => i > 0 && THEMES.includes(s));
  const theme = t > 0 ? segs.splice(t, 1)[0] : '';
  return { screen: segs[0], state: segs.slice(1).join('__'), theme, locale };
}

function dashed(name) {
  const parts = name.split('-');
  if (parts.length < 2) return { screen: name, state: '', theme: '', locale: '' };
  let at = parts.findLastIndex((p) => STATES.includes(p));
  let end = parts.length;
  if (at < 0) {
    const tail = parts.findIndex((_, i) => i >= 2 && LOCALE.test(parts.slice(i).join('-')));
    if (tail >= 0) end = tail;
    at = end - 1;
    if (at >= 2 && THEMES.includes(parts[at])) at--;
  }
  const rest = parts.slice(at + 1);
  const theme = THEMES.includes(rest[0]) ? rest.shift() : '';
  return { screen: parts.slice(0, at).join('-') || name, state: parts[at], theme, locale: rest.join('-') };
}

const shots = readdirSync(src)
  .filter((f) => MIME[extname(f).toLowerCase()])
  .map((file) => {
    const ext = extname(file).toLowerCase();
    const name = file.slice(0, -ext.length);
    const buf = readFileSync(join(src, file));
    return { file, ext, ...(name.includes('__') ? underscored(name) : dashed(name)), buf, px: size(buf, ext) };
  });
if (!shots.length) {
  console.error(`asst-screens: no images in ${src} (looked for ${Object.keys(MIME).join(' ')})`);
  process.exit(1);
}

const rank = (s) => (STATES.includes(s) ? STATES.indexOf(s) : -1);
shots.sort((a, b) =>
  a.screen.localeCompare(b.screen) || rank(a.state) - rank(b.state)
  || a.locale.localeCompare(b.locale) || a.file.localeCompare(b.file));
shots.forEach((s, i) => (s.n = i + 1));

const esc = (s) => String(s).replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
const screens = [...new Set(shots.map((s) => s.screen))];
const locales = [...new Set(shots.map((s) => s.locale).filter(Boolean))].sort();
const themes = THEMES.filter((t) => shots.some((s) => s.theme === t));
const bar = (group, items) => `
    <div class="group">${items.map(([key, label]) =>
      `<button type="button" data-${group}="${esc(key)}">${esc(label)}</button>`).join('')}</div>`;
const filters = [
  locales.length > 1 ? bar('locale', [...locales.map((l) => [l, languageName(l)]), ['all', ui.locales]]) : '',
  themes.length > 1 ? bar('mode', [...themes.map((t) => [t, ui[t]]), ['all', ui.themes]]) : '',
  screens.length > 1 ? bar('screen', [['all', ui.screens], ...screens.map((s) => [s, screenLabel(s)])]) : '',
].join('');

const sections = screens.map((screen) => {
  const cells = shots.filter((s) => s.screen === screen).map((s) => {
    const label = [s.state && stateLabel(s.state), themes.length > 1 && ui[s.theme], locales.length > 1 && s.locale].filter(Boolean).join(' · ') || s.file;
    const px = s.px ? `${s.px[0]} × ${s.px[1]}` : '';
    return `
      <figure id="cell-${s.n}" data-locale="${esc(s.locale)}" data-mode="${esc(s.theme)}">
        <button type="button" class="shot" data-n="${s.n}" aria-label="#${s.n}">
          <img src="data:${MIME[s.ext]};base64,${s.buf.toString('base64')}" alt="${esc(screenLabel(screen))} — ${esc(label)}" loading="lazy" decoding="async">
        </button>
        <figcaption><b>#${s.n}</b> ${esc(label)}<code>${esc(s.file)}${px ? ' · ' : ''}${esc(px)}</code></figcaption>
      </figure>`;
  }).join('');
  return `
    <section data-screen="${esc(screen)}">
      <h2>${esc(screenLabel(screen))}<span class="count"></span></h2>
      <div class="grid">${cells}
      </div>
    </section>`;
}).join('');

const title = labels.title || `Screens — ${slug}`;
// CJK sentences run on with no space between them.
const summary = labels.summary ? labels.summary + (/^(zh|ja)/.test(lang) ? '' : ' ') : '';
const html = `<!doctype html>
<html lang="${esc(lang)}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)}</title>
<style>
  :root { --bg: #f6f6f3; --surface: #ffffff; --text: #1d2421; --muted: #5d6963; --line: #dde2de; --accent: #2f6f5e; --accent-fg: #ffffff; --shade: rgb(0 0 0 / .82); color-scheme: light; }
  @media (prefers-color-scheme: dark) {
    :root:not([data-theme="light"]) { --bg: #141917; --surface: #1c2320; --text: #e5ebe7; --muted: #9aa8a1; --line: #2c3632; --accent: #7cc4ad; --accent-fg: #0f1513; --shade: rgb(0 0 0 / .9); color-scheme: dark; }
  }
  :root[data-theme="dark"] { --bg: #141917; --surface: #1c2320; --text: #e5ebe7; --muted: #9aa8a1; --line: #2c3632; --accent: #7cc4ad; --accent-fg: #0f1513; --shade: rgb(0 0 0 / .9); color-scheme: dark; }
  * { box-sizing: border-box; }
  body { margin: 0; padding: 0 16px 48px; background: var(--bg); color: var(--text); font: 14px/1.55 system-ui, -apple-system, "PingFang TC", "Noto Sans TC", "Hiragino Sans", sans-serif; }
  header { padding-block: 24px 8px; max-width: 72ch; }
  h1 { font-size: 1.5rem; margin: 0 0 6px; text-wrap: balance; }
  header p { margin: 0; color: var(--muted); }
  section { padding-block: 20px 4px; }
  h2 { font-size: 1.1rem; margin: 0 0 12px; }
  .bar { position: sticky; top: 0; z-index: 1; display: flex; flex-wrap: wrap; gap: 8px 16px; padding: 12px 0; background: var(--bg); border-bottom: 1px solid var(--line); }
  .group { display: flex; flex-wrap: wrap; gap: 6px; }
  .bar button { font: inherit; font-size: 0.85rem; padding: 5px 12px; border-radius: 999px; border: 1px solid var(--line); background: var(--surface); color: var(--text); cursor: pointer; }
  .bar button[aria-pressed="true"] { background: var(--accent); border-color: var(--accent); color: var(--accent-fg); }
  .bar button:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
  [hidden] { display: none !important; }
  .grid { display: grid; gap: 20px 16px; grid-template-columns: repeat(auto-fill, minmax(min(100%, 220px), 1fr)); align-items: start; }
  figure { margin: 0; display: flex; flex-direction: column; gap: 6px; min-width: 0; }
  figure:target img { outline: 3px solid var(--accent); }
  .shot { display: block; width: 100%; padding: 0; border: 0; background: none; cursor: zoom-in; }
  .shot img { display: block; width: 100%; height: auto; border-radius: 10px; border: 1px solid var(--line); background: var(--surface); }
  figcaption { font-size: 0.85rem; }
  figcaption code { display: block; font: 0.75rem ui-monospace, Menlo, monospace; color: var(--muted); overflow-wrap: anywhere; }
  #full { position: fixed; inset: 0; z-index: 2; display: none; overflow: auto; background: var(--shade); cursor: zoom-out; }
  #full.open { display: block; }
  #full img { display: block; margin: 0 auto; max-width: none; }
  #full p { position: sticky; top: 0; margin: 0; padding: 8px 16px; color: #fff; background: rgb(0 0 0 / .6); font-size: 13px; }
</style>
</head>
<body>
<header>
  <h1>${esc(title)}</h1>
  <p>${esc(summary)}${esc(ui.summary(shots.length, screens.length))}</p>
</header>${filters ? `
<div class="bar" role="toolbar" aria-label="${esc(ui.filter)}">${filters}
</div>` : ''}
<main>${sections}
</main>
<div id="full" role="dialog" aria-modal="true"><p></p><img alt=""></div>
<script>
  const count = ${JSON.stringify(ui.count(0))};
  const pick = { locale: ${JSON.stringify(locales[0] ?? 'all')}, mode: ${JSON.stringify(themes[0] ?? 'all')}, screen: 'all' };
  try { pick.locale = localStorage.getItem('screens-locale') || pick.locale; } catch (e) {}
  if (!document.querySelector('[data-locale="' + CSS.escape(pick.locale) + '"]')) pick.locale = 'all';
  function filter() {
    for (const b of document.querySelectorAll('.bar button')) {
      const [group, key] = Object.entries(b.dataset)[0];
      b.setAttribute('aria-pressed', String(pick[group] === key));
    }
    for (const sec of document.querySelectorAll('main section')) {
      let shown = 0;
      for (const fig of sec.querySelectorAll('figure')) {
        fig.hidden = ['locale', 'mode'].some((g) => pick[g] !== 'all' && fig.dataset[g] !== '' && fig.dataset[g] !== pick[g]);
        if (!fig.hidden) shown++;
      }
      sec.querySelector('.count').textContent = count.replace('0', shown);
      sec.hidden = !shown || (pick.screen !== 'all' && sec.dataset.screen !== pick.screen);
    }
  }
  for (const b of document.querySelectorAll('.bar button')) b.addEventListener('click', () => {
    const [group, key] = Object.entries(b.dataset)[0];
    pick[group] = key;
    if (group === 'locale') try { localStorage.setItem('screens-locale', key); } catch (e) {}
    filter();
  });
  filter();
  const all = [...document.querySelectorAll('.shot')];
  let shots = all;
  const full = document.getElementById('full');
  const big = full.querySelector('img');
  let at = -1;
  function show(i) {
    at = (i + shots.length) % shots.length;
    const img = shots[at].querySelector('img');
    big.src = img.src;
    big.alt = img.alt;
    // One image pixel per device pixel: the rendered resolution, not scaled up or down.
    big.onload = () => { big.style.width = big.naturalWidth / devicePixelRatio + 'px'; };
    full.querySelector('p').textContent = '#' + shots[at].dataset.n + ' ' + img.alt;
    full.classList.add('open');
    full.scrollTo(0, 0);
  }
  // ← → step through the cells the filters leave visible.
  all.forEach((b) => b.addEventListener('click', () => {
    shots = all.filter((s) => !s.closest('[hidden]'));
    show(shots.indexOf(b));
  }));
  full.addEventListener('click', () => full.classList.remove('open'));
  addEventListener('keydown', (e) => {
    if (!full.classList.contains('open')) return;
    if (e.key === 'Escape') full.classList.remove('open');
    if (e.key === 'ArrowRight') show(at + 1);
    if (e.key === 'ArrowLeft') show(at - 1);
  });
</script>
</body>
</html>
`;

const here = dirname(fileURLToPath(import.meta.url));
const root = execFileSync('bash', [join(here, 'root.sh')], { encoding: 'utf8' }).trim();
const out = join(root, '.claude/.assistant/tasks', slug, 'screens.html');
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, html);
console.log(out);
