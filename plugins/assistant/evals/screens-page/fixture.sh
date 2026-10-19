#!/usr/bin/env bash
# Scaffold for the eval workspace. Runs only under --scaffold / evals/run.sh.
set -euo pipefail
git init -q
mkdir -p .claude shots empty
touch .claude/assistant.md
echo notes > shots/README.md
# Four states of one screen, named so that alphabetical order is not state order, and a second screen.
node - <<'JS'
const { deflateSync } = require('node:zlib');
const { writeFileSync } = require('node:fs');
const table = Array.from({ length: 256 }, (_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
const crc = (b) => { let c = ~0; for (const x of b) c = table[(c ^ x) & 255] ^ (c >>> 8); return ~c >>> 0; };
const chunk = (type, data) => {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type), data]);
  const sum = Buffer.alloc(4); sum.writeUInt32BE(crc(body));
  return Buffer.concat([len, body, sum]);
};
const png = (name, w, h, shade) => {
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 0;
  const raw = Buffer.alloc((w + 1) * h, shade); for (let y = 0; y < h; y++) raw[y * (w + 1)] = 0;
  writeFileSync(`shots/${name}`, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr), chunk('IDAT', deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]));
};
png('inbox--populated--zh-TW.png', 390, 844, 200);
png('inbox--empty--zh-TW.png', 390, 844, 230);
png('inbox--error--zh-TW.png', 390, 844, 120);
png('inbox--loading--zh-TW.png', 390, 844, 180);
png('settings--populated--en.png', 390, 600, 90);
JS
