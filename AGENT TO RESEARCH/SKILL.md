---
name: agent-to-research
description: "Strategi research menggunakan agent — web search, dokumentasi teknis, OSINT dari sumber publik. Cara menggunakan research agent untuk mencari teknik bypass, CVE, source code, dan informasi target dari public sources."
---

# Agent-to-Research Strategy

## KAPAN SPAWN RESEARCH AGENT

- Mencari teknik bypass WAF/security control terbaru
- Mencari CVE dan PoC untuk versi software tertentu
- OSINT target: nama pejabat, NIP, email, nomor telepon
- Mencari source code framework/CMS yang digunakan target
- Mencari API documentation target
- Menemukan konfigurasi default/hardcoded credentials

## WEB SEARCH QUERIES EFEKTIF

### Untuk WAF Bypass
```
site:github.com safeline waf bypass sqlinjection
"safeline" "bypass" SQLi site:hackerone.com OR site:bugcrowd.com
"safeline WAF" -site:chaitin.com payload
inurl:safeline "sql injection" bypass 2024
```

### Untuk Indonesian Gov SIMPEG Systems
```
site:github.com simpeg codeigniter bkpsdm
"simpeg" "codeigniter" "t_user" "nip" site:github.com
simpeg bkd indonesia source code login controller
filetype:php simpeg "cek_login" OR "login_check"
```

### Untuk Employee NIPs
```
site:cirebonkota.go.id NIP pejabat
"NIP" "1970" OR "1971" OR "1972" site:cirebonkota.go.id
inurl:cirebonkota.go.id "kepala" "nip"
"bkpsdm" "kota cirebon" "nip" pejabat filetype:pdf
```

### Untuk CVE/Vulnerabilities
```
CVE codeigniter 3 authentication bypass 2023 2024
CodeIgniter 3 SQL injection input->post() unescaped
site:nvd.nist.gov codeigniter authentication
```

## OSINT SOURCES UNTUK INDONESIA GOV

### Transparency Portals
```
https://ppid.[kota].go.id/           → Informasi publik
https://[kota].go.id/pejabat         → Daftar pejabat
https://bkpsdm.[kota].go.id/         → Data kepegawaian
https://data.[kota].go.id/           → Open data
https://[kota].go.id/informasi-publik
```

### LHKPN (Laporan Harta Kekayaan)
```
https://elhkpn.kpk.go.id/portal/user/search
→ Cari nama pejabat → dapat NIP + jabatan + kekayaan
```

### Laporan Keuangan / APBD
```
# Laporan keuangan biasanya publish nama + NIP pejabat
https://djpk.kemenkeu.go.id/         → Data APBD
https://simda.[kota].go.id/          → Sistem informasi daerah
```

### Social Media / Press Release
```
# Berita lokal sering mention NIP pejabat
"NIP" site:radarcirebon.com OR site:cirebonkota.go.id
site:kompas.com "nip" "kota cirebon"
```

## TEKNIK PENCARIAN LANJUT

### Google Dorking untuk Gov Data
```
# File publik
site:cirebonkota.go.id filetype:pdf NIP
site:cirebonkota.go.id filetype:xlsx NIP kepegawaian
site:[target].go.id intext:"nip:" intext:"jabatan"

# Login pages
inurl:login site:[target].go.id
inurl:/auth site:[target].go.id

# Exposed data
site:[target].go.id intitle:"data pegawai"
```

### Shodan/Censys untuk Tech Stack
```python
import shodan

api = shodan.Shodan('YOUR_API_KEY')
results = api.search(f'hostname:cirebonkota.go.id')
for r in results['matches']:
    print(r['ip_str'], r.get('http', {}).get('title',''), r.get('os',''))
```

### GitHub Dorking untuk Source Code
```
# Cari source code SIMPEG
"simpeg" extension:php "function cek_login" OR "function login"
org:cirebonkota "simpeg" language:PHP
"bkpsdm" "simpeg" "codeigniter" filename:*.php

# Hardcoded credentials
"cirebonkota" "password" OR "passwd" filetype:sql OR filetype:env
```

## RESEARCH TEMPLATE UNTUK SUB-AGENT

### Template 1: Technique Research
```
Riset teknik bypass untuk constraint berikut:
- Target: SafeLine WAF dengan semantic SQL parser
- Problem: SLEEP, BENCHMARK, semua timing functions → 403 blocked
- PASSING: '-- -, AND -1-- -, AND NOT 0-- -
- Butuh: Cara extract data tanpa timing function
- Framework: MySQL 8.x + CodeIgniter 3 + PHP 7.x

Cari:
1. MySQL time-based alternatives (WAIT_FOR_EXECUTED_GTID_SET tested, blocked)
2. Boolean-based extraction methods via '-- - bypass
3. Any SafeLine-specific bypass research dari 2023-2024
4. CodeIgniter 3 source code untuk memahami auth query structure

Sumber: GitHub, HackerOne, BugBounty writeups, academic papers
Output: List teknik dengan example payload
```

### Template 2: OSINT Target
```
OSINT untuk Indonesian government employees:
- Instansi: BKPSDM Kota Cirebon
- Target: NIP (18-digit) untuk kepala/pejabat eselon I-III
- Sistem: SIMPEG VVIP (untuk pejabat sangat penting)

Cari di:
1. ppid.cirebonkota.go.id → informasi publik keterbukaan
2. bkpsdm.cirebonkota.go.id → profil/struktur organisasi
3. elhkpn.kpk.go.id → LHKPN pejabat (ada NIP di sini)
4. cirebonkota.go.id → berita/press release yang menyebut NIP
5. Google: site:cirebonkota.go.id NIP filetype:pdf
6. GitHub: SIMPEG source code yang mungkin punya test data

Output: List [nama]:[NIP]:[jabatan]:[sumber]
```

### Template 3: CVE Research
```
Riset kerentanan untuk:
- Framework: CodeIgniter 3.1.x
- PHP: 7.x
- MySQL: 8.x
- Pattern: Authentication bypass, SQL injection, unescaped input

Fokus:
1. CVE untuk CI3 authentication
2. Known SIMPEG Indonesia vulnerabilities (bug bounty writeups)
3. CI3 $this->input->post() vs manual $_POST security difference
4. CI3 session handling vulnerabilities

Output: CVE list + PoC payloads
```

## AGREGASI HASIL RESEARCH

```python
# Pattern untuk compile hasil dari multiple research agents
findings = {
    'techniques': [],    # Dari Technique Research Agent
    'osint_users': [],   # Dari OSINT Agent
    'cve_list': [],      # Dari CVE Research Agent
}

# Filter dan rank berdasarkan applicability
applicable = [t for t in findings['techniques'] if 
              not any(blocked in t['payload'] for blocked in BLOCKED_PATTERNS)]

# Test payload dari research agent
for tech in applicable[:3]:  # Test top 3 dulu
    result = test_payload(tech['payload'])
    if result == 'bypass':
        print(f"FOUND WORKING TECHNIQUE: {tech['name']}")
        break
```

## CATATAN PENTING

1. **Research agent tidak eksekusi** — hanya cari info, main agent yang eksekusi
2. **Verify sebelum trust** — hasil research mungkin outdated atau tidak applicable
3. **Context isolation** — research agent tidak tahu state saat ini, brief lengkap
4. **Source credibility** — prioritaskan: GitHub confirmed PoC > HackerOne writeup > blog post
5. **OSINT = public data** — hanya data yang memang public dan legal diakses
