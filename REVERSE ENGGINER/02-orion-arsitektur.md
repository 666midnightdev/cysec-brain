# Orion ESTECH — Arsitektur & Format File

## Gambaran Umum
```
Orion.exe (native Windows app)
  └── WebView2 embedded
       └── app HTTPS → estech server
            ├── Katalog model: brand/model list
            ├── File .opdf  → Schematic (PDF vektor, terenkripsi)
            └── File .opcb  → Board/Guideline (PNG raster, terenkripsi)
```

## Format File

### .opdf (Schematic & Layout 2D)
- Konten: **PDF vektor** — bisa langsung dibuka di Acrobat/Edge setelah extract
- Ukuran: beberapa MB hingga 20+ MB per file (50+ halaman)
- Enkripsi: dikupas oleh Orion.exe sebelum render ke WebView2

### .opcb (Board/Guideline)  
- Konten: **PNG raster** resolusi sangat tinggi
- Ukuran: 10–100 MB per file
- Resolusi: bisa 40–100 MP (contoh: 11693×8268 = 97 MP)
- Enkripsi: dikupas oleh Orion.exe, hasil di memori sebelum render

## Alur Dekripsi (dari analisis frida)

```
Orion.exe membaca .opdf/.opcb dari server
  → dekripsi di memori native (sebelum WebView2)
  → hasil: raw PDF bytes atau raw PNG bytes ada di memori
  → Frida bisa scan dan dump sebelum WebView2 render
```

Titik tangkap ideal: **setelah dekripsi, sebelum render** — inilah yang dipakai Frida scan.

## Path File di Memori

Orion menyimpan path file yang sedang dibuka di memori dengan format:
```
<NamaModel> <Kategori>.opdf
<NamaModel> <Kategori>.opcb
```
Contoh:
```
Samsung SM-A716S Schematic.opdf
Apple iPhone 13 Pro Layout 2D.opdf
Xiaomi Redmi Note 13 Pro Guideline.opcb
```

Cara temukan: scan ASCII string dengan suffix `.opdf` atau `.opcb`, ambil 90 byte sebelumnya.

## 4 Kategori Konten

| Kategori | Ekstensi | Format | Keterangan |
|---|---|---|---|
| Schematic | .opdf | PDF vektor | Diagram rangkaian elektronik |
| Layout 2D | .opdf | PDF vektor | PCB top-down view + nama komponen |
| Guideline / Board | .opcb | PNG raster | Foto PCB resolusi tinggi |
| Diode Value | .opdf | PDF | Tabel nilai ukur dioda |

## Catatan Reverse dari Frida Logs
- File PDF ada di range memori `rw-` dan terkadang `r--`
- Magic `%PDF-` cukup andal untuk deteksi
- Footer `%%EOF` selalu ada di akhir PDF valid dari Orion
- PNG selalu punya IHDR chunk — cek dimension untuk filter gambar kecil (icon, thumbnail)
- JPEG board: resolusi minimum filter 600×400, maksimum 20000×20000

## Lookup File: `_seen.log`
File log yang ditulis Frida selama scan:
```
Samsung SM-A716S Schematic
Samsung SM-A716S Layout 2D
Apple iPhone 13 Pro Guideline
```
Satu baris per model+kategori yang berhasil dideteksi dari memori.
Dipakai `organize-cap.py` untuk korelasi waktu jika prefix nama file tidak ada.

## Referensi Kode
- `/root/ai-brain/BUGHUNT/ORION/src/frida-capture.js` — scanner utama
- `/root/ai-brain/BUGHUNT/ORION/src/frida_all.js` — versi lengkap dengan lebih banyak hook
- `/root/ai-brain/BUGHUNT/ORION/logs/trace.log` — log frida trace dari session riil
- `/root/ai-brain/BUGHUNT/ORION/logs/catalog.txt` — katalog model dari server
