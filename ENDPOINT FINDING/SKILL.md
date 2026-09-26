---
name: endpoint-finding
description: "Teknik penemuan endpoint tersembunyi — directory/file bruteforce, JS analysis, API discovery, CI3/Laravel/Django routing, parameter fuzzing. Gunakan di fase recon aktif untuk memperluas attack surface."
---

# Endpoint Finding Reference

## 1. DIRECTORY & FILE DISCOVERY

### Tools
```bash
# gobuster (paling cepat)
gobuster dir -u https://target.com -w /usr/share/wordlists/dirb/big.txt \
    -x php,html,txt,bak,old,sql -t 50 -o gobuster_out.txt \
    --proxy socks5://127.0.0.1:9050

# ffuf (lebih powerful, bisa fuzz parameter)
ffuf -u https://target.com/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt \
    -mc 200,301,302,403 -o ffuf_out.json -of json

# feroxbuster (rekursif)
feroxbuster -u https://target.com -w wordlist.txt -t 50 --proxy socks5://127.0.0.1:9050

# dirsearch
python3 dirsearch.py -u https://target.com -e php,html,js,txt -t 20
```

### Wordlists
```
/usr/share/seclists/Discovery/Web-Content/
├── raft-medium-directories.txt     (50K entries, seimbang)
├── raft-large-directories.txt      (100K+, comprehensive)
├── directory-list-2.3-medium.txt   (classic)
├── api/api-endpoints.txt           (API endpoints)
└── api/objects.txt                 (REST object names)

# Indo gov specific wordlist:
data, pegawai, pejabat, laporan, dokumen, surat, kepegawaian,
admin, administrator, login, auth, dashboard, profile, profil,
api, rest, service, v1, v2, backend
```

## 2. CODEIGNITER 3 (CI3) ROUTING

CI3 menggunakan URL routing: `/controller/method/param1/param2`

### Common CI3 Patterns
```
/login           → LoginController::index()
/auth            → AuthController::index() (POST only)
/auth/login      → AuthController::login()
/auth/logout     → AuthController::logout()
/dashboard       → DashboardController::index()
/pegawai         → PegawaiController::index()
/pegawai/detail/1 → PegawaiController::detail($id=1)
/user            → UserController::index()
/api/pegawai     → ApiController::pegawai()
/profil/edit/1   → ProfilController::edit($id=1)
/laporan/generate → LaporanController::generate()
/report/download/filename → ReportController::download($filename)
```

### Enumeration Command
```bash
# CI3 specific paths
gobuster dir -u https://target.com -w ci3_paths.txt

# ci3_paths.txt:
login
auth
dashboard
welcome
pegawai
user
admin
api
data
laporan
report
export
download
upload
foto
profile
profil
setting
pengaturan
absensi
cuti
tunjangan
kenaikan
mutasi
pensiun
formasi
```

### CI3 URL Tricks
```
# CI3 default: index.php/ (bisa di-suppress dengan .htaccess)
https://target.com/index.php/login
https://target.com/index.php/auth
https://target.com/index.php/dashboard

# Dengan suppress:
https://target.com/login
https://target.com/auth
```

## 3. JAVASCRIPT ANALYSIS

```bash
# Extract endpoints dari JS files
# Download semua JS
wget -r -l1 -A js https://target.com

# Grep untuk endpoints
grep -r "url\|fetch\|ajax\|axios\|get\|post" *.js | grep -E "(/[a-zA-Z]+)+" | head -50

# Tool: LinkFinder
python3 linkfinder.py -i https://target.com -d -o cli 2>/dev/null | grep "https://target"

# Tool: getallurls (gau)
gau target.com | grep -E "\.(php|asp|aspx|do|action)"
```

## 4. API DISCOVERY

```bash
# Common API paths
/api/
/api/v1/
/api/v2/
/rest/
/graphql
/swagger
/swagger.json
/swagger-ui.html
/api-docs
/openapi.json
/docs

# Swagger/OpenAPI discovery
curl https://target.com/swagger.json 2>/dev/null | python3 -m json.tool | grep '"path"'
curl https://target.com/api-docs
```

### API Parameter Fuzzing
```bash
# Fuzz parameter values
ffuf -u "https://target.com/api/user?id=FUZZ" -w /tmp/ids.txt \
    -mc 200 -fc 404

# Fuzz parameter names
ffuf -u "https://target.com/api/FUZZ=1" -w /usr/share/seclists/Discovery/Web-Content/api/parameters.txt
```

## 5. HEADER-BASED DISCOVERY

```bash
# Check X-Forwarded-For bypass
curl -H "X-Forwarded-For: 127.0.0.1" https://target.com/admin/
curl -H "X-Real-IP: 127.0.0.1" https://target.com/admin/
curl -H "X-Original-URL: /admin" https://target.com/

# Check common debug endpoints
curl -H "X-Debug: true" https://target.com/
curl -H "X-Debug-Mode: 1" https://target.com/
```

## 6. PASSIVE ENDPOINT DISCOVERY

```bash
# Wayback Machine
curl "https://web.archive.org/cdx/search/cdx?url=target.com/*&output=text&fl=original&collapse=urlkey"

# Google dorking
site:target.com inurl:api OR inurl:admin OR inurl:login
site:target.com filetype:php

# GitHub
github.com/search?q=target.com+filename:.env OR filename:config.php

# Shodan
shodan search hostname:target.com
```

## 7. SIMPEG-SPECIFIC ENDPOINTS (Indonesia Gov)

```
# Login/Auth
/login
/auth
/auth/login
/index.php/login
/index.php/auth

# Data pegawai (post-auth)
/pegawai
/pegawai/data
/pegawai/list
/pegawai/detail/{nip}
/pegawai/profil
/api/pegawai
/data-pegawai
/master/pegawai

# Reports (sering vulnerable)
/laporan
/laporan/generate
/laporan/download
/cetak
/cetak/sk
/cetak/surat
/export/excel
/export/pdf
/download/{filename}    ← Path traversal!

# Upload (sering vulnerable)
/upload
/pegawai/upload_foto
/foto/upload

# Admin
/admin
/administrator
/superadmin
/simpeg-admin

# API (GraphQL atau REST)
/api
/api/v1
/api/pegawai
/api/auth
```

## 8. PARAMETER INJECTION POINTS

```bash
# Setelah endpoint ditemukan, test tiap parameter
# URL parameters
https://target.com/pegawai/detail?id=1
https://target.com/laporan?bulan=1&tahun=2024
https://target.com/download?file=report.pdf  ← Path traversal!

# Test:
# SQLi: id=1 AND 1=2--+-
# XSS: id=<script>alert(1)</script>
# IDOR: id=1 → id=2 (different user data?)
# Path traversal: file=../../etc/passwd
# SSRF: url=http://internal.server/
```

## CHECKLIST ENDPOINT FINDING

1. ☐ Gobuster/ffuf dengan wordlist standar
2. ☐ CI3/framework-specific paths
3. ☐ JavaScript analysis (LinkFinder)
4. ☐ Wayback Machine / gau historical URLs
5. ☐ Swagger/API docs discovery
6. ☐ Google dorking
7. ☐ Header-based admin bypass
8. ☐ Response analysis: 403 bisa jadi endpoint ada, cuma blocked
9. ☐ Subdomain enumeration (endpoint bisa di subdomain berbeda)
