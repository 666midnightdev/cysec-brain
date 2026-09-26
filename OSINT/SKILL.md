---
name: osint
description: "OSINT untuk pentest — Google dorking, LHKPN/gov data Indonesia, Shodan/Censys, Github leaks, social media, domain recon. Fokus pada Indonesia government targets: NIP pegawai, struktur organisasi, teknologi stack, credentials leak."
---

# OSINT Reference

## 1. GOOGLE DORKING

### Basic Operators
```
site:        → batasi ke domain
filetype:    → tipe file
inurl:       → teks di URL
intitle:     → teks di judul halaman
intext:      → teks di body
-            → exclude
OR           → atau
"exact"      → exact phrase
```

### Gov Indonesia — Employee Data
```
# NIP di PDF/dokumen
site:[instansi].go.id filetype:pdf "NIP"
site:[instansi].go.id filetype:xlsx "NIP"
site:[instansi].go.id filetype:doc "daftar pegawai"

# Profil pejabat
site:[instansi].go.id "kepala bidang" "NIP"
site:[instansi].go.id intitle:"profil" "nip:"
"[instansi]" "NIP" "jabatan" filetype:pdf

# Laporan yang bocor NIP
"[kota]" "daftar pns" OR "data pegawai" filetype:pdf NIP

# Contoh Cirebon:
site:cirebonkota.go.id NIP filetype:pdf
site:cirebonkota.go.id "kepala" NIP
"bkpsdm kota cirebon" NIP pejabat
```

### Credentials & Config
```
site:github.com "[target.com]" password OR passwd OR credential
site:github.com "[target.com]" "db_password" OR "DB_PASS"
site:pastebin.com "[target.com]" password
"[target.com]" filetype:env OR filetype:sql "password"
"[IP/domain]" "username" "password" -site:target.com
```

### Login Pages
```
site:[target].go.id inurl:login
site:[target].go.id intitle:"login" OR intitle:"masuk"
inurl:simpeg.[target].go.id login
```

---

## 2. INDONESIA GOV — SUMBER DATA PUBLIK

### LHKPN KPK (Laporan Harta Kekayaan)
```
URL: https://elhkpn.kpk.go.id/portal/user/search
Data: Nama pejabat, instansi, jabatan, NIP
Cara: Search nama pejabat → dapat NIP lengkap!

# Python scraper
import requests
r = requests.post('https://elhkpn.kpk.go.id/portal/user/search',
    data={'query': 'kepala bkpsdm kota cirebon', 'page': 1})
# Parse JSON response
```

### PPID (Pejabat Pengelola Informasi dan Dokumentasi)
```
URL: https://ppid.[instansi].go.id/
URL: https://ppid.[kota].go.id/
Data: Informasi publik, struktur org, data kepegawaian
Fokus: Download laporan/dokumen → cari NIP
```

### BKN (Badan Kepegawaian Negara)
```
URL: https://www.bkn.go.id/
Data: Pengumuman seleksi CPNS (bisa ada NIP dalam SK)
Cari: SK penetapan NIP untuk CPNS [tahun] [instansi]
```

### Simda/SIKPD (Sistem Keuangan Daerah)
```
# Laporan keuangan yang publish nama+NIP bendahara
https://djpk.kemenkeu.go.id/
https://sikd.kemendagri.go.id/
```

### Portal Berita Lokal (untuk nama pejabat)
```
# Berita lokal sering mention nama dan jabatan pejabat
# Cari nama → lalu cari NIP di LHKPN

Radar Cirebon:    radarcirebon.com
Pikiran Rakyat:   pikiran-rakyat.com
detikNews:        detik.com/regional/jawa-barat
TribunJabar:      tribunjabar.id
```

---

## 3. SHODAN / CENSYS

```python
import shodan

# Shodan
api = shodan.Shodan('API_KEY')

# Cari semua server di domain
results = api.search('hostname:cirebonkota.go.id')
for r in results['matches']:
    print(f"IP: {r['ip_str']}")
    print(f"Port: {r['port']}")
    print(f"OS: {r.get('os','unknown')}")
    print(f"Banner: {r.get('data','')[:200]}")
    print(f"Vulns: {r.get('vulns', {})}")

# Cari berdasarkan IP
info = api.host('103.105.142.246')
print(info)
```

```bash
# Shodan CLI
shodan search hostname:cirebonkota.go.id
shodan host 103.105.142.246

# Censys (via browser atau API)
# https://search.censys.io/
# Query: services.tls.certificates.leaf_data.subject.common_name=cirebonkota.go.id
```

---

## 4. SUBDOMAIN ENUMERATION

```bash
# amass (paling comprehensive)
amass enum -d cirebonkota.go.id -o subdomains.txt

# subfinder
subfinder -d cirebonkota.go.id -o subdomains.txt

# assetfinder
assetfinder cirebonkota.go.id | tee subdomains.txt

# Certificate Transparency (crt.sh)
curl "https://crt.sh/?q=%.cirebonkota.go.id&output=json" | jq '.[].name_value' | sort -u

# Wordlist-based
gobuster dns -d cirebonkota.go.id -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt

# Indonesia gov common subdomains
www, mail, email, ftp, webmail, admin, portal, simpeg, bkpsdm, ppid,
sippd, eoffice, esign, lkjip, apbd, simda, sikpd, sipkd, blud,
data, opendata, opd, dinas, badan, cpns, asn
```

---

## 5. GITHUB OSINT

```bash
# Cari source code target
github.com/search?q=[target.com]&type=code
github.com/search?q=[target]+[SYSTEM NAME]&type=code&l=PHP

# TruffleHog (secrets scanner)
trufflehog github --repo=https://github.com/org/repo

# Gitrob
gitrob --github-access-token TOKEN analyze organization

# git-dumper (jika .git exposed)
git-dumper https://target.com/.git/ ./recovered-repo
```

---

## 6. WAYBACK MACHINE

```bash
# Get all URLs ever crawled
curl "https://web.archive.org/cdx/search/cdx?url=*.cirebonkota.go.id/*&output=text&fl=original&collapse=urlkey" | head -100

# Visualize
https://web.archive.org/web/*/cirebonkota.go.id

# Download old version of target
waybackurls target.com | tee urls.txt
cat urls.txt | grep "\.php\|\.asp" | sort -u
```

---

## 7. SOCIAL MEDIA OSINT

```bash
# LinkedIn: cari pegawai target instansi
# Query: site:linkedin.com/in "BKPSDM Kota Cirebon"
# Tujuan: nama → LHKPN untuk NIP

# Facebook: cari halaman resmi
# Tujuan: foto kegiatan → badge dengan NIP visible

# Instagram: akun resmi instansi
# Tujuan: foto dengan badge pegawai
```

---

## 8. EMAIL DISCOVERY

```bash
# hunter.io
curl "https://api.hunter.io/v2/domain-search?domain=cirebonkota.go.id&api_key=KEY"

# theHarvester
theHarvester -d cirebonkota.go.id -b google,bing,linkedin

# Email format guessing (Indonesia gov)
# Format: [nama.depan]@[instansi].go.id
# Format: [nama.depan.nama.belakang]@[instansi].go.id
```

---

## WORKFLOW OSINT UNTUK PENTEST GOV

```
1. ENUMERATION DOMAIN
   └── crt.sh + amass → semua subdomain
   
2. TECH STACK IDENTIFICATION
   └── Wappalyzer, headers, JS files → framework/CMS/CMS version
   
3. EMPLOYEE NIP DISCOVERY
   ├── LHKPN KPK → nama+NIP pejabat
   ├── PPID → dokumen publik dengan NIP
   ├── Google dorking → PDF/dokumen bocor
   └── Berita lokal → nama pejabat → LHKPN lookup

4. CREDENTIAL LEAK SEARCH
   ├── GitHub dorking → source code + hardcoded creds
   ├── Pastbin → email + password combo
   └── HaveIBeenPwned → email breach check

5. INFRASTRUCTURE MAPPING
   └── Shodan + Censys → IP, ports, services, vulnerabilities
```

---

## NOTES INDONESIA-SPECIFIC

```
NIP Format (18 digit): YYYYMMDDYYYYMMZGGG
- YYYYMMDD: tanggal lahir
- YYYYMM: tahun/bulan pengangkatan (CPNS atau PNS)
- Z: jenis kelamin (1=pria, 2=wanita)
- GGG: nomor urut (001-999)

Contoh: 196705151997031002
= Lahir 15 Mei 1967
= Diangkat Maret 1997
= Laki-laki
= Nomor urut 002
```
