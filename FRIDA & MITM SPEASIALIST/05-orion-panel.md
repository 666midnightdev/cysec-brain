# Panel Kontrol Python + Frida API — OrionCapture

## Arsitektur
```
orion_panel.py (tkinter GUI)
  ├── _boot(): tunggu Orion.exe, lalu attach
  ├── _start_frida(pid): frida.attach(pid) + load script
  ├── _tick(): monitor tiap 2 detik
  │    ├── cek Orion PID
  │    ├── cek frida alive
  │    ├── auto-reattach kalau PID berubah
  │    └── auto-organize kalau ada file baru
  └── do_organize(): pindah file ke output/<model>/
```

## Key Pattern: Frida Python API

```python
import frida

session = frida.attach("Orion.exe")          # atau frida.attach(pid)
# atau: frida.attach(pid) -- lebih stabil

session.on("detached", on_detached_callback)  # handle jika proses mati

# Baca JS dari file
with open("frida-capture.js", "r") as f:
    js_src = f.read()

script = session.create_script(js_src)
script.on("message", lambda msg, data: None)  # abaikan message output
script.load()  # mulai eksekusi

# Stop:
script.unload()
session.detach()
```

## Pattern: Patch Path ke JS Sebelum Load

JS file punya placeholder path yang perlu diganti sesuai mesin:

```python
import re

def prepare_js():
    brd_esc = (BRDD + "\\").replace("\\", "\\\\")  # D:\\OrionTool\\data\\board\\
    pdf_esc = (PDFD + "\\").replace("\\", "\\\\")

    with open("frida-capture.js", "r") as f:
        js = f.read()
    js = re.sub(r'const BRD = "[^"]*";', f'const BRD = "{brd_esc}";', js)
    js = re.sub(r'const PDF = "[^"]*";', f'const PDF = "{pdf_esc}";', js)
    with open("_frida_run.js", "w", encoding="ascii", errors="replace") as f:
        f.write(js)
    return js
```

## Pattern: Deteksi Proses via tasklist

```python
import subprocess, re

CREATE_NO_WINDOW = 0x08000000

def orion_pid():
    try:
        out = subprocess.check_output(
            ["tasklist", "/FI", "IMAGENAME eq Orion.exe", "/FO", "CSV", "/NH"],
            creationflags=CREATE_NO_WINDOW,
            stderr=subprocess.DEVNULL,
        ).decode(errors="replace")
        for line in out.splitlines():
            m = re.search(r'"Orion\.exe","(\d+)"', line)
            if m:
                return int(m.group(1))
    except Exception:
        pass
    return None
```

## Pattern: Auto-Organize File Baru

Di `_tick()` yang jalan tiap 2 detik:

```python
cur_counts = (pdf_count, png_count + jpg_count)
if alive and cur_counts != self._last_counts and not self._organizing:
    self._last_counts = cur_counts
    self._organizing = True
    threading.Thread(target=self._bg_organize, daemon=True).start()
```

## Pattern: Organize Berdasarkan Prefix Nama File

File disimpan dengan format `model__kat__jenis_n.ext`:

```python
def do_organize():
    for fn in files:
        parts = fn.split("__", 2)
        if len(parts) >= 2 and parts[0] not in ("_", ""):
            model_name = safe(parts[0] + " " + parts[1])
        elif n_seen:
            # Fallback: korelasi waktu dengan _seen.log
            model_name = safe(seen[min(int(i * n_seen / n_files), n_seen - 1)])
        else:
            model_name = "_lain"
        dst_dir = os.path.join(OUTD, model_name)
        shutil.copy2(src, dst)
```

## PyInstaller Bundle Frida

Karena pakai `import frida` (bukan subprocess), PyInstaller bisa bundle segalanya:

```powershell
# Harus pakai Python yang SAMA dengan instalasi frida
# Cek: python -c "import frida; print(frida.__version__)"

python -m PyInstaller `
    --onefile --windowed `
    --name OrionCapture `
    --collect-all frida `
    orion_panel.py
```

**Penting:** `--collect-all frida` bundle semua DLL native frida ke dalam exe.

## Lokasi File
- Source terbaru: `/root/orion-bedah/OrionTool/dist/orion_panel.py`
- Frida JS: `/root/orion-bedah/OrionTool/dist/frida-capture.js`
- Exe tercompile: `D:\OrionTool\bin\OrionCapture.exe` (di Windows)
