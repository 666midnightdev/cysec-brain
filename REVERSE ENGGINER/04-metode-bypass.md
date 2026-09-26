# Metode Bypass Enkripsi — Tanpa Crack License

## Prinsip Utama
> **Jangan coba crack enkripsi.** Biarkan aplikasi melakukannya, lalu ambil hasilnya.

Ini prinsip "render-and-grab" — tunggu sampai app sudah render data ke memori atau
sudah mengirim plaintext, baru tangkap.

## 3 Titik Tangkap

### 1. Memory Dump (Frida) — Paling Universal
**Kapan pakai:** App mendekripsi ke memori sebelum render (Orion, hampir semua app)

**Cara:**
```javascript
// Scan memori untuk magic bytes
Memory.scanSync(rg.base, rg.size, '25 50 44 46 2d')  // %PDF-
Memory.scanSync(rg.base, rg.size, '89 50 4e 47 0d 0a 1a 0a')  // PNG
```

**Keuntungan:** Tidak perlu tahu format enkripsi, tidak perlu tahu key

**Kelemahan:** Hanya dapat output final (tidak dapat metadata seperti nama model)

---

### 2. Worker Message Hook (JS Injection) — Untuk WebView2
**Kapan pakai:** App berbasis WebView2/Electron yang pakai Web Worker untuk decrypt (Borneo)

**Cara:**
```javascript
const _orig = Worker.prototype.postMessage;
Worker.prototype.postMessage = function(msg, transfer) {
  if (msg.binaryData || msg.password) {
    // Kirim ke local server via fetch
    fetch('/__capture__', { method: 'POST', body: JSON.stringify(msg) });
  }
  return _orig.apply(this, arguments);
};
```

**Keuntungan:** Dapat plaintext + key + metadata dalam satu langkah

**Kelemahan:** Butuh mitmproxy untuk inject JS; setup lebih kompleks

---

### 3. API Response Intercept (mitmproxy) — Untuk Konten via HTTPS
**Kapan pakai:** File dikirim via HTTPS yang belum terenkripsi (atau enkripsi ringan)

**Cara:**
```python
def response(self, flow):
    if "target-api.com/download" in flow.request.url:
        with open(f"cap_{n}.bin", "wb") as f:
            f.write(flow.response.content)
```

**Keuntungan:** Simpel, langsung dapat file
**Kelemahan:** Hanya kalau konten belum encrypted di level aplikasi

---

## Decision Tree

```
App berbasis native (Delphi/C++/Go)?
  └── Ya → Frida memory scan
App berbasis WebView2/Electron?
  ├── Worker decrypt? → mitmproxy JS injection hook
  ├── API HTTPS? → mitmproxy response intercept
  └── Memory render? → Frida + WebView2 process scan
```

## Anti-Patterns (Jangan Dilakukan)
| Pendekatan | Masalah |
|---|---|
| Reverse enkripsi dari static analysis | Terlalu lama, VMProtect bikin mustahil |
| Crack JWT/license | JWT expire cepat, tidak scalable |
| Patch binary | Merusak app, perlu ulang tiap update |
| Screenshot/OCR | Kualitas buruk, tidak dapat data vektor |

## Tools
| Tool | Fungsi |
|---|---|
| `frida` | Dynamic instrumentation, memory scan |
| `mitmdump` | HTTPS intercept + JS inject |
| `mitmproxy` | UI interaktif untuk mitmproxy |
| `frida-tools` | CLI tools frida (frida-ps, frida-trace, dll) |
| `pycryptodome` | Crypto Python (AES, HMAC, SHA256) |
| `pyinstaller` | Bundle Python + frida jadi exe |

## Setup Cepat (Windows)
```powershell
pip install frida-tools mitmproxy pycryptodome pyinstaller
```

## Referensi Proyek
- Orion (memory scan): `/root/orion-bedah/`
- Borneo (mitmproxy+worker): `/root/borneo-bedah/`
