# Frida vs mitmproxy — Kapan Pakai Mana

## Frida
**Apa:** Dynamic instrumentation — injeksi kode JS ke proses yang sedang jalan.
**Pakai untuk:**
- Scan memori cari asset terdekripsi (PDF, PNG, JPEG)
- Hook fungsi native (C/C++/Delphi) yang decrypt/render konten
- Ambil data SETELAH dekripsi, sebelum dikirim ke renderer

**Perintah dasar:**
```
frida -n NamaProses.exe -l script.js       # attach ke nama
frida -p 1234 -l script.js                 # attach ke PID
frida -f NamaProses.exe -l script.js       # spawn + attach
```

**Python API (lebih bersih, bisa di-bundle):**
```python
import frida
session = frida.attach("NamaProses.exe")   # atau attach(pid)
script = session.create_script(js_source)
script.on("message", lambda msg, data: print(msg))
script.load()
```

## mitmproxy / mitmdump
**Apa:** HTTP/HTTPS proxy yang bisa intercept dan modifikasi traffic.
**Pakai untuk:**
- Sadap request/response antara WebView2 dan server
- Capture JWT, token, API key dari header
- Modifikasi response (inject JS, ubah data)
- Ekstrak file yang dikirim via HTTPS

**Perintah dasar:**
```
mitmdump -s addon.py --listen-port 8080
mitmproxy --listen-port 8080             # UI interaktif
```

**Addon Python:**
```python
from mitmproxy import http
class MyAddon:
    def response(self, flow: http.HTTPFlow):
        if "target.com" in flow.request.pretty_url:
            data = flow.response.content
            # proses data...
addons = [MyAddon()]
```

## Kombinasi: Frida + mitmproxy
Dipakai di OrionTool versi PowerShell (`OrionPanel.ps1`):
1. mitmproxy menangkap `OPEN|model|hash` dari bridge WebView2 → tahu model apa yang dibuka
2. Frida scan memori → ambil file terdekripsi
3. Hasilnya digabung: file dinamai sesuai model dari mitmproxy

Di OrionCapture (versi portable):
- Hanya Frida — nama model didapat dari scan string `.opdf/.opcb` di memori
- Tidak butuh mitmproxy sama sekali

## Pemilihan Strategi

| Situasi | Pilihan |
|---|---|
| Konten ada di memori setelah render | Frida memory scan |
| Konten dikirim lewat HTTPS | mitmproxy intercept |
| Worker JS mendekripsi konten | mitmproxy hook di batas worker |
| Butuh portable (1 exe) | Frida Python API + PyInstaller |
| Butuh metadata (nama model) | mitmproxy atau scan string di memori |
