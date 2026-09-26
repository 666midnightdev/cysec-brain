# mitmproxy + WebView2 — Teknik dari BorneoTool

## Arsitektur Borneo Schematics
```
Borneo Schematics.exe (Delphi + VMProtect)
  └── WebView2 (browser embedded)
       └── app.hostborneo.org (web app)
            ├── JS: Ud() → POST /proxy/<menu> → dapat stream URL
            ├── Fetch URL → ZIP WinZip-AES-256
            ├── Dp(JWT) → derive password ZIP + pcbe
            └── pcbDecryptWorker.postMessage({binaryData, password})
                 └── Worker: AES-CBC decrypt → board object
```

## Titik Tangkap (dari `mitm_borneo_final.py`)
Tangkap di **batas pesan Worker** — bukan di level HTTP, tapi via injeksi JS ke WebView2.

### Setup Proxy
```python
# mitm_borneo_final.py
from mitmproxy import http
import os, json, base64

CAP_DIR = r"D:\BorneoTool\cap"

class BorneoAddon:
    def response(self, flow: http.HTTPFlow):
        url = flow.request.pretty_url
        
        # 1. Tangkap JWT dari header Authorization
        auth = flow.request.headers.get("authorization", "")
        if auth.startswith("Bearer "):
            jwt = auth[7:]
            save_token(jwt)
        
        # 2. Tangkap stream ZIP
        if "/stream/" in url and flow.response.content:
            name = url.split("/")[-1]
            path = os.path.join(CAP_DIR, "streams", f"{name}.zip")
            with open(path, "wb") as f:
                f.write(flow.response.content)
        
        # 3. Inject JS ke halaman untuk hook Worker
        ct = flow.response.headers.get("content-type", "")
        if "text/html" in ct:
            inject_worker_hook(flow)

addons = [BorneoAddon()]
```

### Injeksi JS Hook Worker
```javascript
// Di-inject ke halaman sebelum Worker dibuat
(function() {
  const _orig = Worker.prototype.postMessage;
  Worker.prototype.postMessage = function(msg, transfer) {
    // Tangkap pesan ke Worker (binaryData + password)
    if (msg && msg.binaryData) {
      fetch('/__workcap__', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({
          password: msg.password,
          size: msg.binaryData.byteLength
        })
      });
      // Kirim binaryData sebagai arraybuffer
      const blob = new Blob([msg.binaryData]);
      const fd = new FormData();
      fd.append('data', blob);
      fd.append('password', msg.password || '');
      fetch('/__pcbcap__', { method: 'POST', body: fd });
    }
    return _orig.apply(this, arguments);
  };
  
  // Hook postMessage BALIK dari Worker (hasil board)
  const _handler = window.onmessage;
  window.addEventListener('message', function(e) {
    if (e.data && e.data.components) {
      fetch('/__boardcap__', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify(e.data)
      });
    }
  });
})();
```

### Tangkap di Addon
```python
def request(self, flow: http.HTTPFlow):
    # Tangkap pcbe binary + password
    if flow.request.path == "/__pcbcap__":
        form = flow.request.multipart_form
        pw = form.get(b"password", b"").decode()
        data_part = ...  # ambil file dari form
        n = self._pcbe_n
        self._pcbe_n += 1
        path = os.path.join(CAP_DIR, "pcbe", f"{n}.bin")
        with open(path, "wb") as f:
            f.write(data_part)
        with open(os.path.join(CAP_DIR, "pcbe", f"{n}.pw"), "w") as f:
            f.write(pw)
        flow.response = http.Response.make(200, b"ok")
    
    # Tangkap board JSON hasil decode
    if flow.request.path == "/__boardcap__":
        board = json.loads(flow.request.content)
        n = self._board_n
        self._board_n += 1
        path = os.path.join(CAP_DIR, "board", f"{n}.json")
        with open(path, "w") as f:
            json.dump(board, f)
        flow.response = http.Response.make(200, b"ok")
```

## Setup Sertifikat mitmproxy (Windows)
```powershell
# Generate CA (otomatis saat mitmdump pertama kali jalan)
mitmdump --listen-port 8081

# Install CA ke Windows (run as admin atau via certutil user)
certutil -addstore -f Root "$env:USERPROFILE\.mitmproxy\mitmproxy-ca-cert.cer"

# Set proxy sistem
$reg = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
Set-ItemProperty $reg ProxyEnable 1
Set-ItemProperty $reg ProxyServer "127.0.0.1:8081"

# Matikan proxy setelah selesai
Set-ItemProperty $reg ProxyEnable 0
```

## Pelajaran dari Borneo (Jebakan)
1. **Endpoint harus cocok persis** — kalau JS inject ke `/__pwcap__` tapi addon handle `/__pcbcap__`, data dibuang
2. **JWT cepat expire** — jangan andalkan JWT untuk decrypt offline; tangkap pcbe+password langsung
3. **Borneo pakai VMProtect** — hook di level JS jauh lebih mudah dari hook native
4. **WebView2 ikut proxy sistem Windows** — set `HKCU\...\Internet Settings` sebelum buka app
5. **stream_large_bodies** — wajib set di mitmdump untuk file besar: `--set stream_large_bodies=20m`

## Jalankan
```powershell
# VPS kirim toolkit
scp -i /root/.ssh/orion_win mitm_borneo_final.py midnight@100.82.62.82:'D:/BorneoTool/'

# Di Windows (via SSH)
mitmdump -s D:\BorneoTool\mitm_borneo_final.py --listen-port 8081 --set stream_large_bodies=20m
```
