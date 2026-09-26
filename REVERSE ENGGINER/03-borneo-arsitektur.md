# Borneo Schematics — Arsitektur & Enkripsi

## Gambaran Umum
```
Borneo Schematics.exe (Delphi + VMProtect)
  └── WebView2 → app.hostborneo.org
       ├── Auth: JWT (expire ~5 menit, auto-refresh)
       ├── Katalog: POST /proxy/<region>/<kategori>
       │    → {data: {url: "https://borneoasia.com/stream/<token>"}}
       ├── Download: fetch stream URL
       │    → ZIP WinZip-AES-256 (stored, 1 file: pcbe_<hex>)
       └── Decode: pcbDecryptWorker
            ├── Password = Dp(JWT)
            └── Decrypt pcbe → board object (JSON-like)
```

## Enkripsi Multi-Lapis

### Layer 1: ZIP WinZip-AES-256
- Container format: ZIP dengan enkripsi AES-256 (WinZip extension)
- Password derivasi dari JWT:
  ```
  zip_pw = HMAC-SHA1(jwt_payload, jwt_sig)[0:20] + '-' + [20:31]
  ```
- Isi ZIP: 1 file bernama `pcbe_<hex>`

### Layer 2: pcbe (ProtoCircuit Binary Encrypted)
- Password:
  ```
  pcb_pw = HMAC-SHA1('vector:' + jwt_payload, jwt_sig)[0:20] + '@' + [20:31]
  ```
- Verifikasi: `HMAC(pw, payload) == tag` di header
- Enkripsi: AES-CBC dengan IV per blok
- Header format:
  ```
  [0:4]  = jumlah baris (BE uint32)
  [4:8]  = reserved
  [8:12] = jumlah blok (BE uint32)
  [12:]  = blok: IV(16) + len(4 BE) + ciphertext
  ```
- Key: `SHA256(pcb_pw)`
- Hasil: teks baris (COMP/NETDEF/CP/FV/LAYER/…)

### Format Teks pcbe (setelah decrypt)
```
COMP|C1|100nF|0402|x=123.4|y=456.7|rot=0|layer=TOP
NETDEF|VCC|red
CP|C1|pad1=VCC|pad2=GND
FV|R1|0=100k|1=4.7k|...
```
Parser: `/root/ai-brain/BUGHUNT/BORNEO/src/borneo_parse.py`

## Kenapa JWT Approach Gagal
1. JWT expire ~5 menit → password berubah terus
2. JWT yang tercapture via mitmproxy bukan JWT EXACT yang dipakai saat fetch stream
3. Timestamp mismatch → password salah → ZIP tidak bisa dibuka

## Solusi: Tangkap di Batas Worker

Tangkap **setelah** ZIP dibuka dan pcbe terdekripsi, tepat saat JavaScript mengirim data ke Web Worker:

```javascript
// Di dalam app JS (app.hostborneo.org)
pcbDecryptWorker.postMessage({
  binaryData: pcbeBytes,  // pcbe sudah ter-unzip tapi belum ter-decrypt
  password: pcb_pw        // password AES yang sudah diderivasi
})
```

Dengan hook `Worker.prototype.postMessage`, kita tangkap:
- `binaryData` = pcbe bytes
- `password` = key AES

Dan tangkap BALIK hasilnya:
```javascript
worker.onmessage = function(e) {
  // e.data = board object (components, nets, pads, values)
  // Inilah yang kita mau
}
```

## Jalur Tangkap Utama (yang Berhasil)
```
mitmproxy inject JS hook
  → Worker.postMessage hook → capture pcbe + password
  → Worker onmessage hook → capture board JSON
  → POST ke /__pcbcap__ + /__boardcap__ pada mitmproxy
  → Disimpan ke disk
```

## Format Board JSON (output final)
```json
{
  "components": [
    {"ref": "C1", "value": "100nF", "footprint": "0402", "x": 123.4, "y": 456.7}
  ],
  "nets": [
    {"name": "VCC", "color": "red", "pads": ["C1.1", "R1.2"]}
  ],
  "diode_values": [
    {"ref": "D1", "anode": 0.45, "cathode": 0.0}
  ]
}
```

## Referensi Kode
- `/root/ai-brain/BUGHUNT/BORNEO/src/mitm_borneo_final.py` — addon capture final
- `/root/ai-brain/BUGHUNT/BORNEO/src/borneo_offline.py` — decode pcbe offline
- `/root/ai-brain/BUGHUNT/BORNEO/src/borneo_parse.py` — parser format teks pcbe
- `/root/ai-brain/BUGHUNT/BORNEO/src/borneo_core.py` — logic utama
- `/root/ai-brain/BUGHUNT/BORNEO/docs/RUNBOOK.md` — catatan lengkap investigasi
