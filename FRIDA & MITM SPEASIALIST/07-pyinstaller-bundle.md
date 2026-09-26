# PyInstaller Bundle — Frida + tkinter → Satu EXE

## Setup di Windows

**Python yang dipakai:** harus sama dengan Python yang punya `frida` terinstall.

```powershell
# Cek versi & lokasi frida
Get-Command frida | Select-Object Source
# Output: C:\Users\midnight\AppData\Local\Programs\Python\Python313\Scripts\frida.exe

# Pastikan import frida jalan di Python itu
C:\Users\midnight\AppData\Local\Programs\Python\Python313\python.exe -c "import frida; print(frida.__version__)"

# Install PyInstaller ke Python yang sama
C:\Users\midnight\AppData\Local\Programs\Python\Python313\python.exe -m pip install pyinstaller
```

## Build Command

```powershell
$py = "C:\Users\midnight\AppData\Local\Programs\Python\Python313\python.exe"
& $py -m PyInstaller `
    --onefile `
    --windowed `
    --name OrionCapture `
    --distpath "D:\OrionTool\bin" `
    --workpath "D:\OrionTool\_build" `
    --specpath "D:\OrionTool\_build" `
    --collect-all frida `
    D:\OrionTool\orion_panel.py
```

**Flag penting:**
- `--onefile` — semua jadi 1 exe
- `--windowed` — tidak muncul CMD window (untuk GUI app)
- `--collect-all frida` — bundle semua DLL native frida (wajib!)
- `--distpath` — tentukan folder output exe

## Ukuran Hasil
| Versi | Ukuran |
|---|---|
| Tanpa frida (Python 3.14, tkinter only) | ~12 MB |
| Dengan frida (Python 3.13, `--collect-all frida`) | ~51 MB |

## Deteksi Frozen vs Script (di kode Python)

```python
import sys, os

# Deteksi apakah sedang jalan sebagai PyInstaller exe
if getattr(sys, 'frozen', False):
    # exe: sys.executable = path ke .exe
    # sys._MEIPASS = folder temp extract (isi bundle)
    exe_dir = os.path.dirname(sys.executable)
    # Cari file bundled di exe_dir, bukan _MEIPASS
    frida_local = os.path.join(exe_dir, "frida.exe")
else:
    # script biasa
    exe_dir = os.path.dirname(os.path.abspath(__file__))
```

## Tips

1. **Versi Python harus cocok** — kalau frida di Python313 tapi build pakai Python314, `import frida` gagal
2. **`--collect-all frida`** wajib karena frida punya native extension (`.pyd`, `.dll`)
3. **frida.exe di Scripts tidak bisa di-bundle** — itu wrapper kecil yang tetap butuh Python; pakai `import frida` saja
4. **tkinter** sudah ada di stdlib, otomatis terbundle
5. **File pendamping** (frida-capture.js, dll) TIDAK otomatis terbundle — simpan di folder yang sama dengan exe

## File Pendamping dalam ZIP

Struktur ZIP final yang benar:
```
OrionCapture.zip
├── OrionCapture.exe    ← semua Python + frida terbundle
├── frida-capture.js    ← JS script yang di-inject ke Orion
├── organize-cap.py     ← opsional: organize manual
├── BACA-DULU.txt       ← panduan
└── START.bat           ← shortcut
```

START.bat isinya cukup:
```batch
@echo off
cd /d "%~dp0"
start "" "%~dp0OrionCapture.exe"
```

## Script PowerShell Lengkap (rebuild + zip)

Tersimpan di: `/root/ai-brain/BUGHUNT/ORION/` atau lihat history di `/root/orion-bedah/`
