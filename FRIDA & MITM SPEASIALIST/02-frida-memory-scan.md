# Frida Memory Scan — Teknik dari OrionTool

## Konsep
Orion.exe mendekripsi file `.opdf` (PDF) dan `.opcb` (board PNG) di memori
sebelum render ke WebView2. Frida scan seluruh memori → cari header format
file yang valid → simpan ke disk.

## Pola Umum

```javascript
"use strict";
const OUT = "C:\\output\\";

// Dapatkan semua memory range yang bisa dibaca
function rngs() {
  let r = [];
  ['rw-', 'r--', 'rwx'].forEach(prot => {
    try { r = r.concat(Process.enumerateRanges(prot)); } catch(e) {}
  });
  return r;
}

// Tulis file dari pointer + panjang
function wr(name, p, len) {
  try {
    const f = new File(name, 'wb');
    const CH = 0x10000;
    for (let o = 0; o < len; o += CH)
      f.write(p.add(o).readByteArray(Math.min(CH, len - o)));
    f.close();
    console.log('[SAVE] ' + name + ' (' + len + ' B)');
  } catch(e) { console.log('[!] ' + e); }
}

// Checksum sederhana untuk dedup
function csum(p, len) {
  try {
    const n = Math.min(len, 4096);
    const b = new Uint8Array(p.readByteArray(n));
    let s = 0;
    for (let i = 0; i < n; i += 7) s = (s + b[i] * (i + 1)) >>> 0;
    return s;
  } catch(e) { return len; }
}
```

## Scan PDF
```javascript
let pi = 0;
const sPdf = new Set();

function scanPdf(rg) {
  // Cari magic %PDF-
  Memory.scanSync(rg.base, rg.size, '25 50 44 46 2d').forEach(m => {
    try {
      const s = m.address;
      const off = s.sub(rg.base).toInt32();
      const win = Math.min(rg.size - off, 24 * 1024 * 1024);
      // Cari %%EOF
      const e = Memory.scanSync(s, win, '25 25 45 4f 46');
      if (!e.length) return;
      const len = e[e.length-1].address.add(5).sub(s).toInt32();
      if (len < 2000 || len > 24*1024*1024) return;
      const k = 'P' + len + '_' + csum(s, len);
      if (sPdf.has(k)) return; sPdf.add(k);
      wr(OUT + 'pdf_' + pi + '_' + len + '.pdf', s, len);
      pi++;
    } catch(e) {}
  });
}
```

## Scan PNG
```javascript
function u32be(p) {
  const b = new Uint8Array(p.readByteArray(4));
  return (b[0]*16777216) + (b[1]<<16) + (b[2]<<8) + b[3];
}
let ai = 0;
const sPng = new Set();

function scanPng(rg) {
  // Magic: \x89PNG\r\n\x1a\n
  Memory.scanSync(rg.base, rg.size, '89 50 4e 47 0d 0a 1a 0a').forEach(h => {
    try {
      // Cek IHDR chunk
      const ih = new Uint8Array(h.address.add(12).readByteArray(4));
      if (!(ih[0]===0x49 && ih[1]===0x48 && ih[2]===0x44 && ih[3]===0x52)) return;
      const w = u32be(h.address.add(16)), ht = u32be(h.address.add(20));
      if (w < 1500 || ht < 1500) return;  // filter terlalu kecil
      // Cari IEND
      const remain = rg.size - h.address.sub(rg.base).toInt32();
      const t = Memory.scanSync(h.address, Math.min(remain, 60*1024*1024), '49 45 4e 44 ae 42 60 82');
      if (!t.length) return;
      const len = t[0].address.add(8).sub(h.address).toInt32();
      const k = 'p' + w + 'x' + ht + '_' + csum(h.address, len);
      if (sPng.has(k)) return; sPng.add(k);
      wr(OUT + 'board_' + ai + '_' + w + 'x' + ht + '.png', h.address, len);
      ai++;
    } catch(e) {}
  });
}
```

## Scan Nama Model dari Memori
Orion menyimpan path file `.opdf`/`.opcb` di memori sebelum buka. Scan string ini:

```javascript
function hx(s) {
  let o = [];
  for (let i = 0; i < s.length; i++)
    o.push(('0' + s.charCodeAt(i).toString(16)).slice(-2));
  return o.join(' ');
}

let currentModel = "", currentKat = "";
const sName = new Set();
const NAMESLOG = OUT + "_seen.log";

function scanNames(rg) {
  ['.opdf', '.opcb'].forEach(ext => {
    try {
      Memory.scanSync(rg.base, rg.size, hx(ext)).forEach(m => {
        try {
          const start = m.address.sub(90);
          const b = new Uint8Array(start.readByteArray(90 + ext.length));
          let s = '';
          for (let i = 0; i < b.length; i++) {
            const c = b[i];
            s += (c >= 32 && c < 127) ? String.fromCharCode(c) : '\n';
          }
          const mm = s.match(/([A-Za-z0-9][A-Za-z0-9 ()._+-]{3,48}?)\s+(Schematic|Layout 2D|Layout|Board|Diode Value|Bitmap|Guideline)(\.opdf|\.opcb)/i);
          if (mm) {
            const mdl = mm[1].trim(), kat = mm[2].trim();
            if (mdl) { currentModel = mdl; currentKat = kat; }
            const nm = mdl + ' ' + kat;
            if (!sName.has(nm)) {
              sName.add(nm);
              try { const f = new File(NAMESLOG, 'a'); f.write(nm + '\n'); f.close(); } catch(e) {}
            }
          }
        } catch(e) {}
      });
    } catch(e) {}
  });
}
```

## Loop Utama
```javascript
let busy = false;
function dump() {
  if (busy) return; busy = true;
  try {
    const ranges = rngs();
    // PENTING: scan nama DULU agar model sudah diset sebelum simpan file
    ranges.forEach(rg => { try { scanNames(rg); } catch(e) {} });
    ranges.forEach(rg => {
      try { scanPdf(rg); } catch(e) {}
      try { scanPng(rg); } catch(e) {}
    });
  } catch(e) {}
  busy = false;
}
setInterval(dump, 4000);  // scan tiap 4 detik
```

## Tips Penting
- **Scan range 'rw-', 'r--', 'rwx'** — banyak data ada di range read-only saat render
- **Dedup dengan checksum** — proses scan di-trigger berkali-kali, file sama akan muncul berulang
- **Ukuran max** — batasi scan window (24MB PDF, 60MB PNG) untuk hindari crash
- **`busy` flag** — cegah concurrent scan yang bisa crash frida
- **Nama file embed model** — format `model__kat__jenis_n.ext` agar organize mudah
- **scanNames SEBELUM scanPdf/scanPng** — model belum diset kalau dibalik
