# RECON — Deep Reconnaissance (Pasif → Aktif)

> Recon = 80% dari kerja. Makin jeli di sini, makin banyak attack surface ketemu. Prinsip: **lebar dulu,
> baru dalam**. Jangan terpaku satu vektor. Catat semua (`| tee recon/<step>.txt`).

## Daftar Isi
1. [Mindset & Alur](#alur)
2. [Dari 1 URL / Config — apa yang langsung dilihat](#dari-url)
3. [Recon Pasif: WHOIS, DNS, ASN](#pasif-dns)
4. [Subdomain Enumeration](#subdomain)
5. [Certificate & CT Logs](#cert)
6. [OSINT: leaks, dork, email, karyawan](#osint)
7. [Content Discovery: JS, endpoint, param, path](#content)
8. [Enum Aktif: port, service, web fingerprint](#aktif)
9. [Cloud & Third-party surface](#cloud-surface)
10. [Checklist "jeli"](#checklist)

---

<a name="alur"></a>
## 1. Alur Recon

```
Seed (domain/URL/IP/nama org)
  → Horizontal: cari SEMUA aset (subdomain, IP, ASN, akuisisi, cloud, repo)
  → Vertical:   per-aset gali dalam (port, tech, endpoint, param, config)
  → Prioritas:  aset menarik = admin/dev/staging/api/vpn/old/legacy/internal
```

Aset "menarik" = yang paling sering rentan: `dev.`, `staging.`, `test.`, `uat.`, `old.`, `legacy.`,
`internal.`, `admin.`, `api.`, `vpn.`, `git.`, `jenkins.`, `jira.`, `grafana.`, `*.s3.`, panel login.

---

<a name="dari-url"></a>
## 2. Dari 1 URL / Config — Apa yang Langsung Dilihat

Begitu dapat satu URL, **jangan langsung nyerang**. Baca dulu semua sinyal gratisan:

```bash
# Header lengkap + redirect chain
curl -sSIL https://$TARGET | tee recon/headers.txt
# Cari: Server, X-Powered-By, Set-Cookie (flags!), CSP, HSTS, CORS, X-*-custom, cache headers

# Body + komentar + tech hints
curl -sSL https://$TARGET | tee recon/index.html
grep -Ei "api|token|key|secret|internal|debug|version|build|env" recon/index.html

# Tech fingerprint
whatweb -a3 https://$TARGET | tee recon/whatweb.txt
# atau: wappalyzer / webanalyze
nuclei -u https://$TARGET -t http/technologies/ -o recon/tech.txt
```

**Config files & metadata sering bocor — cek dulu:**
```bash
for f in robots.txt sitemap.xml security.txt .well-known/security.txt \
  .git/config .env .env.local .env.production config.json config.js \
  appsettings.json web.config wp-config.php.bak backup.zip \
  .DS_Store crossdomain.xml clientaccesspolicy.xml \
  swagger.json openapi.json api-docs graphql .well-known/openid-configuration; do
  echo "== $f =="; curl -sS -o /dev/null -w "%{http_code}\n" https://$TARGET/$f
done | tee recon/config-probe.txt
```

**Yang dicari dari sinyal dasar (ini yang bikin "jeli"):**
- `Set-Cookie` → nama cookie ungkap framework (`PHPSESSID`, `JSESSIONID`, `connect.sid`, `.ASPXAUTH`, `laravel_session`). Flag `HttpOnly`/`Secure`/`SameSite` hilang = temuan.
- `X-Powered-By` / `Server` → versi → cek CVE.
- CSP header → sumber JS/CDN eksternal → surface tambahan.
- Redirect ke domain lain → aset baru.
- Error verbose (stack trace) → path internal, versi, framework.
- Komentar HTML/JS → endpoint tersembunyi, kredensial, TODO dev.
- `.well-known/openid-configuration` → seluruh alur OAuth/OIDC.

---

<a name="pasif-dns"></a>
## 3. Recon Pasif: WHOIS, DNS, ASN

```bash
whois $TARGET | tee recon/whois.txt          # org, email, tanggal, registrar
dig +short A $TARGET; dig +short AAAA $TARGET; dig +short MX $TARGET
dig +short NS $TARGET; dig +short TXT $TARGET  # SPF/DMARC/verifikasi = leak layanan
dig +short CNAME www.$TARGET                    # CNAME → dangling? subdomain takeover
dnsrecon -d $TARGET -t std | tee recon/dnsrecon.txt

# ASN → range IP milik org (aset yang di-host sendiri)
whois -h whois.cymru.com " -v $(dig +short $TARGET | head -1)"
# amass intel untuk ASN → CIDR
amass intel -org "Nama Organisasi" | tee recon/asn.txt
amass intel -asn <ASN> | tee recon/asn-ips.txt
```

**Reverse DNS / IP → domain lain di server yang sama** (virtual host discovery):
```bash
# setelah dapat IP:
curl -sS "https://api.hackertarget.com/reverseiplookup/?q=$IP"
# vhost fuzzing:
ffuf -w subdomains.txt -u https://$IP -H "Host: FUZZ.$TARGET" -fs <baseline-size>
```

---

<a name="subdomain"></a>
## 4. Subdomain Enumeration (horizontal — cari SEMUA)

```bash
# Pasif (banyak sumber, cepat, no-touch)
subfinder -d $TARGET -all -recursive -o recon/subs-passive.txt
amass enum -passive -d $TARGET -o recon/subs-amass.txt
assetfinder --subs-only $TARGET >> recon/subs-passive.txt
# crt.sh langsung:
curl -sS "https://crt.sh/?q=%25.$TARGET&output=json" | jq -r '.[].name_value' | sort -u >> recon/subs-passive.txt

# Aktif brute + permutasi
puredns bruteforce subdomains-top1million.txt $TARGET -r resolvers.txt -w recon/subs-brute.txt
# permutasi (dev1, dev-2, staging-api, dll)
gotator -sub recon/all-subs.txt -perm permutations.txt -depth 1 | puredns resolve -r resolvers.txt

# Gabung + resolve + hidup mana
sort -u recon/subs-*.txt > recon/all-subs.txt
dnsx -l recon/all-subs.txt -a -resp -o recon/resolved.txt
# Mana yang punya web service:
httpx -l recon/all-subs.txt -sc -title -tech-detect -td -location -o recon/live-web.txt
```

**Subdomain takeover** (dangling CNAME → layanan pihak ketiga tidak diklaim):
```bash
subzy run --targets recon/all-subs.txt
nuclei -l recon/all-subs.txt -t http/takeovers/ -o recon/takeover.txt
# Manual: dig CNAME → apakah nunjuk ke S3/GitHub Pages/Heroku/Azure yang 404 "NoSuchBucket" dll
```

---

<a name="cert"></a>
## 5. Certificate & CT Logs

```bash
# CT logs = daftar subdomain gratis dari sertifikat yang pernah diterbitkan
curl -sS "https://crt.sh/?q=%25.$TARGET&output=json" | jq -r '.[].common_name,.[].name_value' | sort -u
# Sertifikat live → SAN (nama alternatif = domain lain)
echo | openssl s_client -connect $TARGET:443 -servername $TARGET 2>/dev/null \
  | openssl x509 -noout -text | grep -A2 "Subject Alternative Name"
# Issuer, tanggal, wildcard? → info organisasi & infra
```

---

<a name="osint"></a>
## 6. OSINT: Leaks, Dork, Email, Karyawan

```bash
# Google/GitHub dorks (jalankan di browser)
#   site:$TARGET ext:php | ext:log | ext:sql | ext:env | ext:bak
#   site:$TARGET intitle:"index of"
#   site:$TARGET inurl:admin | inurl:login | inurl:api | inurl:debug
#   "$TARGET" (di github.com) → hardcoded secret di repo publik

# GitHub secret hunting
trufflehog github --org=<org> --only-verified | tee recon/gh-secrets.txt
gitleaks detect --source=<cloned-repo> -r recon/gitleaks.json

# Email & karyawan → surface phishing/password-spray (kalau in-scope)
# theHarvester -d $TARGET -b all
# Cek email di breach: kredensial reuse (HIBP / dehashed — sesuai scope & legal)

# Wayback / arsip → endpoint & param lama (sering masih hidup!)
waybackurls $TARGET | tee recon/wayback.txt
gau --threads 5 $TARGET | tee -a recon/wayback.txt
# Filter yang menarik:
grep -Ei "\.(json|xml|config|env|sql|bak|old|zip|log)(\?|$)" recon/wayback.txt
grep -Ei "api|token|key|redirect|url=|file=|path=|id=" recon/wayback.txt | sort -u
```

---

<a name="content"></a>
## 7. Content Discovery: JS, Endpoint, Param, Path

**JavaScript = tambang emas** (endpoint tersembunyi, API key, logic):
```bash
# Kumpulkan semua JS
cat recon/live-web.txt | subjs | tee recon/js-files.txt
# atau: hakrawler / katana untuk crawl
katana -u https://$TARGET -jc -d 3 -o recon/crawl.txt

# Ekstrak endpoint & secret dari JS
cat recon/js-files.txt | while read u; do curl -sS "$u"; done > recon/all-js.txt
grep -Eo '"/[a-zA-Z0-9_/.-]+"' recon/all-js.txt | sort -u          # path
grep -Eio '(api[_-]?key|apikey|secret|token|bearer|aws_access)[^,;"]{0,40}' recon/all-js.txt
# Tool otomatis:
# LinkFinder / SecretFinder untuk endpoint & secret di JS
```

**Directory / file brute force:**
```bash
feroxbuster -u https://$TARGET -w raft-medium-directories.txt -x php,asp,aspx,json,bak,zip,old \
  -o recon/ferox.txt --smart
ffuf -w raft-medium-directories.txt -u https://$TARGET/FUZZ -mc 200,204,301,302,401,403 \
  -o recon/ffuf.json
# 403? coba bypass: /admin → /admin/ /admin/. /%2e/admin /admin..;/ + header X-Original-URL
```

**Parameter discovery** (buat nemu param tersembunyi → IDOR/SSRF/LFI):
```bash
arjun -u https://$TARGET/api/endpoint -m GET,POST -o recon/params.txt
# param populer buat dicoba: id, user, file, path, url, redirect, next, page, template, cmd, debug
```

---

<a name="aktif"></a>
## 8. Enum Aktif: Port, Service, Web Fingerprint

```bash
# Port cepat lalu detail (lihat network.md untuk lengkap)
rustscan -a $IP --ulimit 5000 -- -sV -sC -oA scan/full
nmap -Pn -p- --min-rate 5000 -T4 -oA scan/allports $IP
nmap -Pn -sV -sC -p<ports-terbuka> -oA scan/detail $IP

# Web fingerprint lanjutan
whatweb -a3 https://$TARGET
nuclei -u https://$TARGET -t http/ -severity low,medium,high,critical -o scan/nuclei.txt
# CMS spesifik:
# wpscan --url ... --enumerate ap,at,u   (WordPress)
# joomscan / droopescan   (Joomla/Drupal)
```

**Baseline dulu sebelum fuzz** — catat response normal (status, size, timing) biar anomali kelihatan.

---

<a name="cloud-surface"></a>
## 9. Cloud & Third-party Surface

```bash
# S3 / blob bucket dari nama org
# coba: <org>, <org>-dev, <org>-backup, <org>-assets, <org>-prod
aws s3 ls s3://<bucket> --no-sign-request
curl -sS https://<bucket>.s3.amazonaws.com/          # listing publik?
# GCP: https://storage.googleapis.com/<bucket>/
# Azure: https://<acct>.blob.core.windows.net/<container>?restype=container&comp=list

# Deteksi CDN/WAF (pengaruh strategi)
# wafw00f https://$TARGET
```

Detail cloud attack → `references/cloud.md`.

---

<a name="checklist"></a>
## 10. Checklist "Jeli" (jangan lewat satu pun)

- [ ] Baca **semua header** response (custom `X-*`, cache, CORS, cookie flags).
- [ ] Cek **config/metadata files** (.env, .git, swagger, .well-known, backup).
- [ ] Baca **komentar HTML/JS** & seluruh **JS file** (endpoint + secret).
- [ ] **Wayback + gau** untuk endpoint/param lama yang masih hidup.
- [ ] **Semua subdomain** (pasif + brute + permutasi), fokus dev/staging/old/admin.
- [ ] **CT logs & SAN cert** untuk domain tersembunyi.
- [ ] **ASN → IP range** milik org (aset self-hosted).
- [ ] **Subdomain takeover** cek dangling CNAME.
- [ ] **GitHub/Google dork** untuk secret & file bocor.
- [ ] **Param discovery** di endpoint menarik.
- [ ] **Bucket cloud** dengan variasi nama org.
- [ ] Baseline response dicatat sebelum fuzzing.
- [ ] Semua output tersimpan di `recon/` (bukti + bisa diulang).

> **Aturan emas:** kalau belum nemu apa-apa, kamu belum recon cukup dalam. Balik ke JS files, wayback, dan subdomain lapis kedua (subdomain dari subdomain).
