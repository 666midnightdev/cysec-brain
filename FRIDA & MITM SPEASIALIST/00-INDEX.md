# FRIDA & MITM SPECIALIST — Index

Pengetahuan dari dua proyek nyata: **Borneo Schematics** + **Orion ESTECH**.
Keduanya adalah aplikasi EDA desktop berbasis WebView2 (Electron/CEF style).

## Dokumen

| File | Isi |
|---|---|
| [01-konsep-dasar.md](01-konsep-dasar.md) | Frida & mitmproxy: cara kerja, kapan pakai mana |
| [02-frida-memory-scan.md](02-frida-memory-scan.md) | Scan memori cari PDF/PNG/JPEG dari Orion |
| [03-mitm-webview2.md](03-mitm-webview2.md) | Sadap traffic WebView2 dengan mitmproxy (Borneo) |
| [04-worker-boundary.md](04-worker-boundary.md) | Teknik tangkap di batas Web Worker (Borneo) |
| [05-orion-panel.md](05-orion-panel.md) | Panel kontrol Python + Frida API langsung |
| [06-borneo-panel.md](06-borneo-panel.md) | Panel kontrol Python + mitmproxy (Borneo) |
| [07-pyinstaller-bundle.md](07-pyinstaller-bundle.md) | Bundle frida ke exe dengan PyInstaller |

## Referensi Kode

- Kode Borneo: `/root/ai-brain/BUGHUNT/BORNEO/src/`
- Kode Orion: `/root/ai-brain/BUGHUNT/ORION/src/`
- Versi terbaru OrionTool: `/root/orion-bedah/OrionTool/`
- Versi terbaru BorneoTool: `/root/borneo-bedah/BorneoTool/`
