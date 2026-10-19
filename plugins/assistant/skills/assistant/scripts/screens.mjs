#!/usr/bin/env node
// asst-screens — build the ② screens page: one web page showing every rendered
// screenshot as its own image, at its original resolution. The images are
// embedded byte for byte (no re-encoding, no stitching), so nothing is scaled
// down before the founder sees it, and the page is one file that opens anywhere.
//
// Usage: asst-screens <task-slug> <image-dir>   → prints the page's path
//
// Images: .png .jpg .jpeg .webp .gif in <image-dir>, named
// <screen>--<state>[--<locale>].<ext> (e.g. `inbox--empty--zh-TW.png`). The page
// has one section per screen, states in the order empty · loading · error ·
// populated, then any other. Every image gets a number, so the founder can
// answer "which cell" with one. A name without `--` is a screen with no state.
//
// The page lands at <root>/.claude/.assistant/tasks/<slug>/screens.html and is
// overwritten on each run. Exit: 0 = written, 1 = no images, 2 = usage.

import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { dirname, extname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const MIME = { '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp', '.gif': 'image/gif' };
const STATES = ['empty', 'loading', 'error', 'populated'];

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

const shots = readdirSync(src)
  .filter((f) => MIME[extname(f).toLowerCase()])
  .map((file) => {
    const ext = extname(file).toLowerCase();
    const [screen, state = '', ...rest] = file.slice(0, -ext.length).split('--');
    const buf = readFileSync(join(src, file));
    return { file, ext, screen, state, locale: rest.join('--'), buf, px: size(buf, ext) };
  });
if (!shots.length) {
  console.error(`asst-screens: no images in ${src} (looked for ${Object.keys(MIME).join(' ')})`);
  process.exit(1);
}

const rank = (s) => (STATES.includes(s) ? STATES.indexOf(s) : STATES.length);
shots.sort((a, b) =>
  a.screen.localeCompare(b.screen) || rank(a.state) - rank(b.state) || a.state.localeCompare(b.state)
  || a.locale.localeCompare(b.locale) || a.file.localeCompare(b.file));
shots.forEach((s, i) => (s.n = i + 1));

const esc = (s) => String(s).replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
const screens = [...new Set(shots.map((s) => s.screen))];

const sections = screens.map((screen) => {
  const cells = shots.filter((s) => s.screen === screen).map((s) => {
    const label = [s.state, s.locale].filter(Boolean).join(' · ') || s.file;
    const px = s.px ? `${s.px[0]} × ${s.px[1]}` : '';
    return `
      <figure id="cell-${s.n}">
        <button type="button" class="shot" data-n="${s.n}" aria-label="Open #${s.n} at full size">
          <img src="data:${MIME[s.ext]};base64,${s.buf.toString('base64')}" alt="${esc(screen)} — ${esc(label)}" loading="lazy" decoding="async">
        </button>
        <figcaption><b>#${s.n}</b> ${esc(label)}<span>${esc(px)}${px ? ' · ' : ''}${esc(s.file)}</span></figcaption>
      </figure>`;
  }).join('');
  return `
    <section>
      <h2>${esc(screen)}</h2>
      <div class="grid">${cells}
      </div>
    </section>`;
}).join('');

const title = `Screens — ${slug}`;
const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)}</title>
<style>
  :root { --bg: #f7f7f5; --surface: #ffffff; --text: #1d1d1b; --muted: #6b6b66; --line: #e2e2dd; --accent: #2f6fde; --shade: rgb(0 0 0 / .82); color-scheme: light; }
  @media (prefers-color-scheme: dark) {
    :root:not([data-theme="light"]) { --bg: #161615; --surface: #20201f; --text: #ececea; --muted: #9a9a94; --line: #34342f; --accent: #7aa7ff; --shade: rgb(0 0 0 / .9); color-scheme: dark; }
  }
  :root[data-theme="dark"] { --bg: #161615; --surface: #20201f; --text: #ececea; --muted: #9a9a94; --line: #34342f; --accent: #7aa7ff; --shade: rgb(0 0 0 / .9); color-scheme: dark; }
  * { box-sizing: border-box; }
  body { margin: 0; background: var(--bg); color: var(--text); font: 15px/1.5 system-ui, -apple-system, "PingFang TC", "Noto Sans TC", sans-serif; }
  header, main { max-width: 1600px; margin: 0 auto; padding: 0 16px; }
  header { padding-top: 24px; padding-bottom: 8px; }
  h1 { font-size: 22px; margin: 0; }
  header p { margin: 4px 0 0; color: var(--muted); }
  h2 { font-size: 17px; margin: 28px 0 12px; padding-bottom: 6px; border-bottom: 1px solid var(--line); }
  .grid { display: grid; gap: 16px; grid-template-columns: repeat(auto-fill, minmax(min(100%, 360px), 1fr)); align-items: start; }
  figure { margin: 0; background: var(--surface); border: 1px solid var(--line); border-radius: 10px; overflow: hidden; }
  figure:target { outline: 3px solid var(--accent); }
  .shot { display: block; width: 100%; padding: 0; border: 0; background: none; cursor: zoom-in; }
  .shot img { display: block; width: 100%; height: auto; }
  figcaption { padding: 8px 12px; border-top: 1px solid var(--line); }
  figcaption span { display: block; color: var(--muted); font-size: 12px; overflow-wrap: anywhere; }
  #full { position: fixed; inset: 0; z-index: 1; display: none; overflow: auto; background: var(--shade); cursor: zoom-out; }
  #full.open { display: block; }
  #full img { display: block; margin: 0 auto; max-width: none; }
  #full p { position: sticky; top: 0; margin: 0; padding: 8px 16px; color: #fff; background: rgb(0 0 0 / .6); font-size: 13px; }
</style>
</head>
<body>
<header>
  <h1>${esc(title)}</h1>
  <p>${shots.length} images · ${screens.length} screens · click an image for full size (← → to step, Esc to close)</p>
</header>
<main>${sections}
</main>
<div id="full" role="dialog" aria-modal="true" aria-label="Full-size image"><p></p><img alt=""></div>
<script>
  const shots = [...document.querySelectorAll('.shot')];
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
  shots.forEach((b, i) => b.addEventListener('click', () => show(i)));
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
